use std::env;

use actix_web::{web, App, HttpServer};
use sqlx::{postgres::PgConnectOptions, PgPool};

#[actix_web::main]
async fn main() {
    let db_option = PgConnectOptions::new()
        .host(&env::var("DATABASE_HOST").unwrap())
        .username(&env::var("DATABASE_USER").unwrap())
        .password(&env::var("DATABASE_PASSWORD").unwrap());
    let db_pool = PgPool::connect_with(db_option).await.unwrap();

    let server = HttpServer::new(move || {
        App::new()
            .data(db_pool.clone())
            .route("/{crate}", web::get().to(find_crate))
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
    num: String,
    crate_size: Option<i32>,
    license: Option<String>,
}

#[derive(serde::Serialize)]
struct FindCrateResponse {
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
    .map_err(|_| actix_web::error::ErrorInternalServerError("Internal Server Error"))?
    .ok_or_else(|| actix_web::error::ErrorNotFound("Not Found"))?;
    let version_info: VersionInfo = sqlx::query_as(
        "SELECT num, \
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
    .map_err(|_| actix_web::error::ErrorInternalServerError("Internal Server Error"))?;
    let result = FindCrateResponse {
        version: version_info.num,
        description: crate_info.description,
        license: version_info.license,
        crate_size: version_info.crate_size.map(|size| size as u32),
        repository: crate_info.repository,
        documentation: crate_info.documentation,
        homepage: crate_info.homepage,
        updated_at: chrono::DateTime::from_utc(crate_info.updated_at, chrono::Utc),
    };
    Ok(web::Json(result))
}
