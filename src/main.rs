use std::env;

use actix_web::{http::StatusCode, web, App, HttpResponse, HttpServer, ResponseError};
use sqlx::{postgres::PgConnectOptions, PgPool};

#[actix_web::main]
async fn main() {
    env_logger::init();

    let db_option = PgConnectOptions::new()
        .host(&env::var("DATABASE_HOST").unwrap())
        .username(&env::var("DATABASE_USER").unwrap())
        .password(&env::var("DATABASE_PASSWORD").unwrap());
    let db_pool = PgPool::connect_with(db_option).await.unwrap();

    let server = HttpServer::new(move || {
        App::new()
            .data(db_pool.clone())
            .route("/{crate}", web::get().to(find_crate))
            .route("/deps/{version}", web::get().to(dependencies))
    });

    server.bind("0.0.0.0:8080").unwrap().run().await.unwrap();
}

#[derive(sqlx::FromRow)]
struct CrateInfo {
    id: i32,
    description: Option<String>,
    repository: Option<String>,
    documentation: Option<String>,
    homepage: Option<String>,
    updated_at: chrono::NaiveDateTime,
}

#[derive(sqlx::FromRow)]
struct VersionInfo {
    id: i32,
    num: String,
    crate_size: Option<i32>,
    license: Option<String>,
}

#[derive(sqlx::FromRow)]
struct DependencyInfo {
    kind: i32,
}

mod dependency_kind {
    pub const NORMAL: i32 = 0;
    pub const BUILD: i32 = 1;
    pub const DEV: i32 = 2;
}

#[derive(serde::Serialize)]
struct FindCrateResponse {
    version_id: i32,
    version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    description: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    license: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    crate_size: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    repository: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    documentation: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    homepage: Option<String>,
    updated_at: chrono::DateTime<chrono::Utc>,
    dependencies: usize,
    dev_dependencies: usize,
    build_dependencies: usize,
}

#[derive(Debug)]
struct SqlxError(sqlx::Error);

impl std::fmt::Display for SqlxError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

impl ResponseError for SqlxError {
    fn status_code(&self) -> StatusCode {
        StatusCode::INTERNAL_SERVER_ERROR
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code()).body("Internal Server Error")
    }
}

async fn find_crate(
    path: web::Path<String>,
    pool: web::Data<PgPool>,
) -> actix_web::Result<web::Json<FindCrateResponse>> {
    let crate_info: CrateInfo = sqlx::query_as(
        "SELECT id, \
                updated_at, \
                downloads, \
                description, \
                homepage, \
                documentation, \
                repository \
        FROM crates \
        WHERE name = $1",
    )
    .bind(path.as_str())
    .fetch_optional(pool.as_ref())
    .await
    .map_err(SqlxError)?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Not Found"))?;
    let version_info: VersionInfo = sqlx::query_as(
        "SELECT id, \
                num, \
                crate_size, \
                license \
        FROM versions \
        WHERE crate_id = $1 \
        ORDER BY updated_at DESC \
        LIMIT 1",
    )
    .bind(crate_info.id)
    .fetch_one(pool.as_ref())
    .await
    .map_err(SqlxError)?;
    let dependencies: Vec<DependencyInfo> = sqlx::query_as(
        "SELECT kind \
        FROM dependencies \
        WHERE version_id = $1",
    )
    .bind(version_info.id)
    .fetch_all(pool.as_ref())
    .await
    .map_err(SqlxError)?;
    let (dependencies, build_dependencies, dev_dependencies) =
        dependencies
            .iter()
            .fold((0, 0, 0), |(n, b, d), dep| match dep.kind {
                dependency_kind::NORMAL => (n + 1, b, d),
                dependency_kind::BUILD => (n, b + 1, d),
                dependency_kind::DEV => (n, b, d + 1),
                _ => (n, b, d),
            });
    let result = FindCrateResponse {
        version_id: version_info.id,
        version: version_info.num,
        description: crate_info.description,
        license: version_info.license,
        crate_size: version_info.crate_size.map(|size| size as u32),
        repository: crate_info.repository,
        documentation: crate_info.documentation,
        homepage: crate_info.homepage,
        updated_at: chrono::DateTime::from_utc(crate_info.updated_at, chrono::Utc),
        dependencies,
        build_dependencies,
        dev_dependencies,
    };
    Ok(web::Json(result))
}

#[derive(serde::Serialize, sqlx::FromRow)]
struct DependenciesItem {
    name: String,
    req: String,
    optional: bool,
    kind: i32,
}

async fn dependencies(
    path: web::Path<i32>,
    pool: web::Data<PgPool>,
) -> Result<web::Json<Vec<DependenciesItem>>, SqlxError> {
    sqlx::query_as(
        "SELECT name, \
                req, \
                optional, \
                kind \
        FROM dependencies \
        INNER JOIN crates \
            ON dependencies.crate_id = crates.id \
        WHERE version_id = $1",
    )
    .bind(*path)
    .fetch_all(pool.as_ref())
    .await
    .map_err(SqlxError)
    .map(web::Json)
}
