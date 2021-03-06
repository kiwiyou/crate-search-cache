--
-- PostgreSQL database dump
--

-- Dumped from database version 11.8 (Ubuntu 11.8-1.pgdg16.04+1)
-- Dumped by pg_dump version 12.4 (Ubuntu 12.4-1.pgdg18.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: ltree; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS ltree WITH SCHEMA public;


--
-- Name: EXTENSION ltree; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION ltree IS 'data type for hierarchical tree-like structures';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: semver_triple; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.semver_triple AS (
	major numeric,
	minor numeric,
	teeny numeric
);


--
-- Name: canon_crate_name(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.canon_crate_name(text) RETURNS text
    LANGUAGE sql
    AS $_$
                    SELECT replace(lower($1), '-', '_')
                $_$;


--
-- Name: crate_owner_invitations_set_token_generated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crate_owner_invitations_set_token_generated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW.token_generated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
  END
$$;


--
-- Name: diesel_manage_updated_at(regclass); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.diesel_manage_updated_at(_tbl regclass) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    EXECUTE format('CREATE TRIGGER set_updated_at BEFORE UPDATE ON %s
                    FOR EACH ROW EXECUTE PROCEDURE diesel_set_updated_at()', _tbl);
END;
$$;


--
-- Name: diesel_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.diesel_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (
        NEW IS DISTINCT FROM OLD AND
        NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
    ) THEN
        NEW.updated_at := current_timestamp;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: emails_set_token_generated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.emails_set_token_generated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW.token_generated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
  END
$$;


--
-- Name: ensure_crate_name_not_reserved(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_crate_name_not_reserved() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                BEGIN
                    IF canon_crate_name(NEW.name) IN (
                        SELECT canon_crate_name(name) FROM reserved_crate_names
                    ) THEN
                        RAISE EXCEPTION 'cannot upload crate with reserved name';
                    END IF;
                    RETURN NEW;
                END;
                $$;


--
-- Name: ensure_reserved_name_not_in_use(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ensure_reserved_name_not_in_use() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF canon_crate_name(NEW.name) IN (
        SELECT canon_crate_name(name) FROM crates
    ) THEN
        RAISE EXCEPTION 'crate exists with name %', NEW.name;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: random_string(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.random_string(integer) RETURNS text
    LANGUAGE sql
    AS $_$
  SELECT (array_to_string(array(
    SELECT substr(
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
      floor(random() * 62)::int4 + 1,
      1
    ) FROM generate_series(1, $1)
  ), ''))
$_$;


--
-- Name: reconfirm_email_on_email_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.reconfirm_email_on_email_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    IF NEW.email IS DISTINCT FROM OLD.email THEN
      NEW.token := random_string(26);
      NEW.verified := false;
    END IF;
    RETURN NEW;
  END
$$;


--
-- Name: refresh_recent_crate_downloads(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_recent_crate_downloads() RETURNS void
    LANGUAGE sql
    AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY recent_crate_downloads;
$$;


--
-- Name: set_category_path_to_slug(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_category_path_to_slug() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
 NEW.path = text2ltree('root.' || trim(replace(replace(NEW.slug, '-', '_'), '::', '.')));
 RETURN NEW;
END;
    $$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (
        NEW IS DISTINCT FROM OLD AND
        NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
    ) THEN
        NEW.updated_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: set_updated_at_ignore_downloads(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at_ignore_downloads() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_downloads integer;
BEGIN
    new_downloads := NEW.downloads;
    OLD.downloads := NEW.downloads;
    IF (
        NEW IS DISTINCT FROM OLD AND
        NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at
    ) THEN
        NEW.updated_at = CURRENT_TIMESTAMP;
    END IF;
    NEW.downloads := new_downloads;
    RETURN NEW;
END
$$;


--
-- Name: to_semver_no_prerelease(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.to_semver_no_prerelease(text) RETURNS public.semver_triple
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT (
    split_part($1, '.', 1)::numeric,
    split_part($1, '.', 2)::numeric,
    split_part(split_part($1, '+', 1), '.', 3)::numeric
  )::semver_triple
  WHERE strpos($1, '-') = 0
  $_$;


--
-- Name: touch_crate(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_crate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                BEGIN
                    IF TG_OP = 'DELETE' THEN
                        UPDATE crates SET updated_at = CURRENT_TIMESTAMP WHERE
                            id = OLD.crate_id;
                        RETURN OLD;
                    ELSE
                        UPDATE crates SET updated_at = CURRENT_TIMESTAMP WHERE
                            id = NEW.crate_id;
                        RETURN NEW;
                    END IF;
                END
                $$;


--
-- Name: touch_crate_on_version_modified(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_crate_on_version_modified() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (
    TG_OP = 'INSERT' OR
    NEW.updated_at IS DISTINCT FROM OLD.updated_at
  ) THEN
    UPDATE crates SET updated_at = CURRENT_TIMESTAMP WHERE
      crates.id = NEW.crate_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trigger_crates_name_search(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_crates_name_search() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                DECLARE kws TEXT;
                begin
                  SELECT array_to_string(array_agg(keyword), ',') INTO kws
                    FROM keywords INNER JOIN crates_keywords
                    ON keywords.id = crates_keywords.keyword_id
                    WHERE crates_keywords.crate_id = new.id;
                  new.textsearchable_index_col :=
                     setweight(to_tsvector('pg_catalog.english',
                                           coalesce(new.name, '')), 'A') ||
                     setweight(to_tsvector('pg_catalog.english',
                                           coalesce(kws, '')), 'B') ||
                     setweight(to_tsvector('pg_catalog.english',
                                           coalesce(new.description, '')), 'C') ||
                     setweight(to_tsvector('pg_catalog.english',
                                           coalesce(new.readme, '')), 'D');
                  return new;
                end
                $$;


--
-- Name: update_categories_crates_cnt(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_categories_crates_cnt() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ BEGIN IF (TG_OP = 'INSERT') THEN UPDATE categories SET crates_cnt = crates_cnt + 1 WHERE id = NEW.category_id; return NEW; ELSIF (TG_OP = 'DELETE') THEN UPDATE categories SET crates_cnt = crates_cnt - 1 WHERE id = OLD.category_id; return OLD; END IF; END $$;


--
-- Name: update_keywords_crates_cnt(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_keywords_crates_cnt() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF (TG_OP = 'INSERT') THEN
                    UPDATE keywords SET crates_cnt = crates_cnt + 1 WHERE id = NEW.keyword_id;
                    return NEW;
                ELSIF (TG_OP = 'DELETE') THEN
                    UPDATE keywords SET crates_cnt = crates_cnt - 1 WHERE id = OLD.keyword_id;
                    return OLD;
                END IF;
            END
            $$;


SET default_tablespace = '';

--
-- Name: __diesel_schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.__diesel_schema_migrations (
    version character varying(50) NOT NULL,
    run_on timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    token bytea NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    last_used_at timestamp without time zone,
    revoked boolean DEFAULT false NOT NULL
);


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_tokens_id_seq OWNED BY public.api_tokens.id;


--
-- Name: background_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.background_jobs (
    id bigint NOT NULL,
    job_type text NOT NULL,
    data jsonb NOT NULL,
    retries integer DEFAULT 0 NOT NULL,
    last_retry timestamp without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: background_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.background_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: background_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.background_jobs_id_seq OWNED BY public.background_jobs.id;


--
-- Name: badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badges (
    crate_id integer NOT NULL,
    badge_type character varying NOT NULL,
    attributes jsonb NOT NULL
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    category character varying NOT NULL,
    slug character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    crates_cnt integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    path public.ltree NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: crate_owner_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crate_owner_invitations (
    invited_user_id integer NOT NULL,
    invited_by_user_id integer NOT NULL,
    crate_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    token text DEFAULT public.random_string(26) NOT NULL,
    token_generated_at timestamp without time zone
);


--
-- Name: crate_owners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crate_owners (
    crate_id integer NOT NULL,
    owner_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by integer,
    deleted boolean DEFAULT false NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    owner_kind integer NOT NULL,
    email_notifications boolean DEFAULT true NOT NULL
);


--
-- Name: crates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crates (
    id integer NOT NULL,
    name character varying NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    downloads integer DEFAULT 0 NOT NULL,
    description character varying,
    homepage character varying,
    documentation character varying,
    readme character varying,
    textsearchable_index_col tsvector NOT NULL,
    repository character varying,
    max_upload_size integer
);


--
-- Name: crates_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crates_categories (
    crate_id integer NOT NULL,
    category_id integer NOT NULL
);


--
-- Name: crates_keywords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crates_keywords (
    crate_id integer NOT NULL,
    keyword_id integer NOT NULL
);


--
-- Name: dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dependencies (
    id integer NOT NULL,
    version_id integer NOT NULL,
    crate_id integer NOT NULL,
    req character varying NOT NULL,
    optional boolean NOT NULL,
    default_features boolean NOT NULL,
    features text[] NOT NULL,
    target character varying,
    kind integer DEFAULT 0 NOT NULL
);


--
-- Name: dependencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dependencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dependencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dependencies_id_seq OWNED BY public.dependencies.id;


--
-- Name: emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emails (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    token text DEFAULT public.random_string(26) NOT NULL,
    token_generated_at timestamp without time zone
);


--
-- Name: emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.emails_id_seq OWNED BY public.emails.id;


--
-- Name: follows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.follows (
    user_id integer NOT NULL,
    crate_id integer NOT NULL
);


--
-- Name: keywords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.keywords (
    id integer NOT NULL,
    keyword text NOT NULL,
    crates_cnt integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: keywords_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.keywords_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: keywords_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.keywords_id_seq OWNED BY public.keywords.id;


--
-- Name: metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metadata (
    total_downloads bigint NOT NULL
);


--
-- Name: packages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.packages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: packages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.packages_id_seq OWNED BY public.crates.id;


--
-- Name: publish_limit_buckets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publish_limit_buckets (
    user_id integer NOT NULL,
    tokens integer NOT NULL,
    last_refill timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: publish_rate_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publish_rate_overrides (
    user_id integer NOT NULL,
    burst integer NOT NULL
);


--
-- Name: readme_renderings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.readme_renderings (
    version_id integer NOT NULL,
    rendered_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: version_downloads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.version_downloads (
    version_id integer NOT NULL,
    downloads integer DEFAULT 1 NOT NULL,
    counted integer DEFAULT 0 NOT NULL,
    date date DEFAULT ('now'::text)::date NOT NULL,
    processed boolean DEFAULT false NOT NULL
);


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id integer NOT NULL,
    crate_id integer NOT NULL,
    num character varying NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    downloads integer DEFAULT 0 NOT NULL,
    features jsonb DEFAULT '{}'::jsonb NOT NULL,
    yanked boolean DEFAULT false NOT NULL,
    license character varying,
    crate_size integer,
    published_by integer
);


--
-- Name: recent_crate_downloads; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.recent_crate_downloads AS
 SELECT versions.crate_id,
    sum(version_downloads.downloads) AS downloads
   FROM (public.version_downloads
     JOIN public.versions ON ((version_downloads.version_id = versions.id)))
  WHERE (version_downloads.date > date((CURRENT_TIMESTAMP - '90 days'::interval)))
  GROUP BY versions.crate_id
  WITH NO DATA;


--
-- Name: reserved_crate_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reserved_crate_names (
    name text NOT NULL
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id integer NOT NULL,
    login character varying NOT NULL,
    github_id integer NOT NULL,
    name character varying,
    avatar character varying,
    org_id integer,
    CONSTRAINT teams_login_lowercase_ck CHECK (((login)::text = lower((login)::text)))
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    gh_access_token character varying NOT NULL,
    gh_login character varying NOT NULL,
    name character varying,
    gh_avatar character varying,
    gh_id integer NOT NULL,
    account_lock_reason character varying,
    account_lock_until timestamp without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: version_authors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.version_authors (
    id integer NOT NULL,
    version_id integer NOT NULL,
    user_id integer,
    name character varying NOT NULL
);


--
-- Name: version_authors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.version_authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: version_authors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.version_authors_id_seq OWNED BY public.version_authors.id;


--
-- Name: version_owner_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.version_owner_actions (
    id integer NOT NULL,
    version_id integer NOT NULL,
    user_id integer NOT NULL,
    api_token_id integer,
    action integer NOT NULL,
    "time" timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: version_owner_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.version_owner_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: version_owner_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.version_owner_actions_id_seq OWNED BY public.version_owner_actions.id;


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: versions_published_by; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions_published_by (
    version_id integer NOT NULL,
    email character varying NOT NULL
);


--
-- Name: api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_tokens_id_seq'::regclass);


--
-- Name: background_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.background_jobs ALTER COLUMN id SET DEFAULT nextval('public.background_jobs_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: crates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates ALTER COLUMN id SET DEFAULT nextval('public.packages_id_seq'::regclass);


--
-- Name: dependencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dependencies ALTER COLUMN id SET DEFAULT nextval('public.dependencies_id_seq'::regclass);


--
-- Name: emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emails ALTER COLUMN id SET DEFAULT nextval('public.emails_id_seq'::regclass);


--
-- Name: keywords id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keywords ALTER COLUMN id SET DEFAULT nextval('public.keywords_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: version_authors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_authors ALTER COLUMN id SET DEFAULT nextval('public.version_authors_id_seq'::regclass);


--
-- Name: version_owner_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_owner_actions ALTER COLUMN id SET DEFAULT nextval('public.version_owner_actions_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: __diesel_schema_migrations __diesel_schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.__diesel_schema_migrations
    ADD CONSTRAINT __diesel_schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: background_jobs background_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.background_jobs
    ADD CONSTRAINT background_jobs_pkey PRIMARY KEY (id);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (crate_id, badge_type);


--
-- Name: categories categories_category_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_category_key UNIQUE (category);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: crate_owner_invitations crate_owner_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owner_invitations
    ADD CONSTRAINT crate_owner_invitations_pkey PRIMARY KEY (invited_user_id, crate_id);


--
-- Name: crate_owners crate_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owners
    ADD CONSTRAINT crate_owners_pkey PRIMARY KEY (crate_id, owner_id, owner_kind);


--
-- Name: crates_categories crates_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates_categories
    ADD CONSTRAINT crates_categories_pkey PRIMARY KEY (crate_id, category_id);


--
-- Name: crates_keywords crates_keywords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates_keywords
    ADD CONSTRAINT crates_keywords_pkey PRIMARY KEY (crate_id, keyword_id);


--
-- Name: dependencies dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dependencies
    ADD CONSTRAINT dependencies_pkey PRIMARY KEY (id);


--
-- Name: emails emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emails
    ADD CONSTRAINT emails_pkey PRIMARY KEY (id);


--
-- Name: emails emails_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emails
    ADD CONSTRAINT emails_user_id_key UNIQUE (user_id);


--
-- Name: follows follows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT follows_pkey PRIMARY KEY (user_id, crate_id);


--
-- Name: keywords keywords_keyword_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keywords
    ADD CONSTRAINT keywords_keyword_key UNIQUE (keyword);


--
-- Name: keywords keywords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keywords
    ADD CONSTRAINT keywords_pkey PRIMARY KEY (id);


--
-- Name: metadata metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metadata
    ADD CONSTRAINT metadata_pkey PRIMARY KEY (total_downloads);


--
-- Name: crates packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: publish_limit_buckets publish_limit_buckets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_limit_buckets
    ADD CONSTRAINT publish_limit_buckets_pkey PRIMARY KEY (user_id);


--
-- Name: publish_rate_overrides publish_rate_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_rate_overrides
    ADD CONSTRAINT publish_rate_overrides_pkey PRIMARY KEY (user_id);


--
-- Name: readme_renderings readme_renderings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readme_renderings
    ADD CONSTRAINT readme_renderings_pkey PRIMARY KEY (version_id);


--
-- Name: reserved_crate_names reserved_crate_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reserved_crate_names
    ADD CONSTRAINT reserved_crate_names_pkey PRIMARY KEY (name);


--
-- Name: teams teams_github_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_github_id_key UNIQUE (github_id);


--
-- Name: teams teams_login_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_login_key UNIQUE (login);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: versions unique_num; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT unique_num UNIQUE (crate_id, num);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: version_authors version_authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_authors
    ADD CONSTRAINT version_authors_pkey PRIMARY KEY (id);


--
-- Name: version_downloads version_downloads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_downloads
    ADD CONSTRAINT version_downloads_pkey PRIMARY KEY (version_id, date);


--
-- Name: version_owner_actions version_owner_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_owner_actions
    ADD CONSTRAINT version_owner_actions_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: versions_published_by versions_published_by_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions_published_by
    ADD CONSTRAINT versions_published_by_pkey PRIMARY KEY (version_id);


--
-- Name: api_tokens_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_tokens_token_idx ON public.api_tokens USING btree (token);


--
-- Name: crate_owners_not_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX crate_owners_not_deleted ON public.crate_owners USING btree (crate_id, owner_id, owner_kind) WHERE (NOT deleted);


--
-- Name: dependencies_crate_id_version_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dependencies_crate_id_version_id_idx ON public.dependencies USING btree (crate_id, version_id);


--
-- Name: index_crate_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crate_created_at ON public.crates USING btree (created_at);


--
-- Name: index_crate_downloads; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crate_downloads ON public.crates USING btree (downloads);


--
-- Name: index_crate_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crate_updated_at ON public.crates USING btree (updated_at);


--
-- Name: index_crates_categories_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_categories_category_id ON public.crates_categories USING btree (category_id);


--
-- Name: index_crates_categories_crate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_categories_crate_id ON public.crates_categories USING btree (crate_id);


--
-- Name: index_crates_keywords_crate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_keywords_crate_id ON public.crates_keywords USING btree (crate_id);


--
-- Name: index_crates_keywords_keyword_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_keywords_keyword_id ON public.crates_keywords USING btree (keyword_id);


--
-- Name: index_crates_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_crates_name ON public.crates USING btree (public.canon_crate_name((name)::text));


--
-- Name: index_crates_name_ordering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_name_ordering ON public.crates USING btree (name);


--
-- Name: index_crates_name_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_name_search ON public.crates USING gin (textsearchable_index_col);


--
-- Name: index_crates_name_tgrm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_crates_name_tgrm ON public.crates USING gin (public.canon_crate_name((name)::text) public.gin_trgm_ops);


--
-- Name: index_dependencies_crate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dependencies_crate_id ON public.dependencies USING btree (crate_id);


--
-- Name: index_dependencies_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dependencies_version_id ON public.dependencies USING btree (version_id);


--
-- Name: index_follows_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_follows_user_id ON public.follows USING btree (user_id);


--
-- Name: index_keywords_crates_cnt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keywords_crates_cnt ON public.keywords USING btree (crates_cnt);


--
-- Name: index_keywords_keyword; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keywords_keyword ON public.keywords USING btree (keyword);


--
-- Name: index_keywords_lower_keyword; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_keywords_lower_keyword ON public.keywords USING btree (lower(keyword));


--
-- Name: index_recent_crate_downloads_by_downloads; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recent_crate_downloads_by_downloads ON public.recent_crate_downloads USING btree (downloads);


--
-- Name: index_version_authors_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_version_authors_version_id ON public.version_authors USING btree (version_id);


--
-- Name: index_version_downloads_by_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_version_downloads_by_date ON public.version_downloads USING brin (date);


--
-- Name: lower_gh_login; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX lower_gh_login ON public.users USING btree (lower((gh_login)::text));


--
-- Name: path_gist_categories_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX path_gist_categories_idx ON public.categories USING gist (path);


--
-- Name: recent_crate_downloads_crate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX recent_crate_downloads_crate_id ON public.recent_crate_downloads USING btree (crate_id);


--
-- Name: users_gh_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_gh_id ON public.users USING btree (gh_id) WHERE (gh_id > 0);


--
-- Name: categories set_category_path_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_category_path_insert BEFORE INSERT ON public.categories FOR EACH ROW EXECUTE PROCEDURE public.set_category_path_to_slug();


--
-- Name: categories set_category_path_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_category_path_update BEFORE UPDATE OF slug ON public.categories FOR EACH ROW EXECUTE PROCEDURE public.set_category_path_to_slug();


--
-- Name: versions touch_crate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_crate BEFORE INSERT OR UPDATE ON public.versions FOR EACH ROW EXECUTE PROCEDURE public.touch_crate_on_version_modified();


--
-- Name: crates_categories touch_crate_on_modify_categories; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_crate_on_modify_categories AFTER INSERT OR DELETE ON public.crates_categories FOR EACH ROW EXECUTE PROCEDURE public.touch_crate();


--
-- Name: crates_keywords touch_crate_on_modify_keywords; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER touch_crate_on_modify_keywords AFTER INSERT OR DELETE ON public.crates_keywords FOR EACH ROW EXECUTE PROCEDURE public.touch_crate();


--
-- Name: crate_owner_invitations trigger_crate_owner_invitations_set_token_generated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_crate_owner_invitations_set_token_generated_at BEFORE INSERT OR UPDATE OF token ON public.crate_owner_invitations FOR EACH ROW EXECUTE PROCEDURE public.crate_owner_invitations_set_token_generated_at();


--
-- Name: crate_owners trigger_crate_owners_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_crate_owners_set_updated_at BEFORE UPDATE ON public.crate_owners FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();


--
-- Name: crates trigger_crates_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_crates_set_updated_at BEFORE UPDATE ON public.crates FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at_ignore_downloads();


--
-- Name: crates trigger_crates_tsvector_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_crates_tsvector_update BEFORE INSERT OR UPDATE OF updated_at ON public.crates FOR EACH ROW EXECUTE PROCEDURE public.trigger_crates_name_search();


--
-- Name: emails trigger_emails_reconfirm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_emails_reconfirm BEFORE UPDATE ON public.emails FOR EACH ROW EXECUTE PROCEDURE public.reconfirm_email_on_email_change();


--
-- Name: emails trigger_emails_set_token_generated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_emails_set_token_generated_at BEFORE INSERT OR UPDATE OF token ON public.emails FOR EACH ROW EXECUTE PROCEDURE public.emails_set_token_generated_at();


--
-- Name: crates trigger_ensure_crate_name_not_reserved; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_ensure_crate_name_not_reserved BEFORE INSERT OR UPDATE ON public.crates FOR EACH ROW EXECUTE PROCEDURE public.ensure_crate_name_not_reserved();


--
-- Name: reserved_crate_names trigger_ensure_reserved_name_not_in_use; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_ensure_reserved_name_not_in_use BEFORE INSERT OR UPDATE ON public.reserved_crate_names FOR EACH ROW EXECUTE PROCEDURE public.ensure_reserved_name_not_in_use();


--
-- Name: crates_categories trigger_update_categories_crates_cnt; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_categories_crates_cnt BEFORE INSERT OR DELETE ON public.crates_categories FOR EACH ROW EXECUTE PROCEDURE public.update_categories_crates_cnt();


--
-- Name: crates_keywords trigger_update_keywords_crates_cnt; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_keywords_crates_cnt BEFORE INSERT OR DELETE ON public.crates_keywords FOR EACH ROW EXECUTE PROCEDURE public.update_keywords_crates_cnt();


--
-- Name: versions trigger_versions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_versions_set_updated_at BEFORE UPDATE ON public.versions FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at_ignore_downloads();


--
-- Name: api_tokens api_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: crate_owner_invitations crate_owner_invitations_crate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owner_invitations
    ADD CONSTRAINT crate_owner_invitations_crate_id_fkey FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: crate_owner_invitations crate_owner_invitations_invited_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owner_invitations
    ADD CONSTRAINT crate_owner_invitations_invited_by_user_id_fkey FOREIGN KEY (invited_by_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: crate_owner_invitations crate_owner_invitations_invited_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owner_invitations
    ADD CONSTRAINT crate_owner_invitations_invited_user_id_fkey FOREIGN KEY (invited_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: badges fk_badges_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT fk_badges_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: crate_owners fk_crate_owners_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owners
    ADD CONSTRAINT fk_crate_owners_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: crate_owners fk_crate_owners_created_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crate_owners
    ADD CONSTRAINT fk_crate_owners_created_by FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: crates_categories fk_crates_categories_category_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates_categories
    ADD CONSTRAINT fk_crates_categories_category_id FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: crates_categories fk_crates_categories_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates_categories
    ADD CONSTRAINT fk_crates_categories_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: crates_keywords fk_crates_keywords_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates_keywords
    ADD CONSTRAINT fk_crates_keywords_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: crates_keywords fk_crates_keywords_keyword_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates_keywords
    ADD CONSTRAINT fk_crates_keywords_keyword_id FOREIGN KEY (keyword_id) REFERENCES public.keywords(id);


--
-- Name: dependencies fk_dependencies_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dependencies
    ADD CONSTRAINT fk_dependencies_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: dependencies fk_dependencies_version_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dependencies
    ADD CONSTRAINT fk_dependencies_version_id FOREIGN KEY (version_id) REFERENCES public.versions(id) ON DELETE CASCADE;


--
-- Name: emails fk_emails_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emails
    ADD CONSTRAINT fk_emails_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: follows fk_follows_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT fk_follows_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: follows fk_follows_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.follows
    ADD CONSTRAINT fk_follows_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: version_authors fk_version_authors_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_authors
    ADD CONSTRAINT fk_version_authors_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: version_authors fk_version_authors_version_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_authors
    ADD CONSTRAINT fk_version_authors_version_id FOREIGN KEY (version_id) REFERENCES public.versions(id) ON DELETE CASCADE;


--
-- Name: version_downloads fk_version_downloads_version_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_downloads
    ADD CONSTRAINT fk_version_downloads_version_id FOREIGN KEY (version_id) REFERENCES public.versions(id) ON DELETE CASCADE;


--
-- Name: versions fk_versions_crate_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT fk_versions_crate_id FOREIGN KEY (crate_id) REFERENCES public.crates(id) ON DELETE CASCADE;


--
-- Name: versions fk_versions_published_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT fk_versions_published_by FOREIGN KEY (published_by) REFERENCES public.users(id);


--
-- Name: publish_limit_buckets publish_limit_buckets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_limit_buckets
    ADD CONSTRAINT publish_limit_buckets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: publish_rate_overrides publish_rate_overrides_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_rate_overrides
    ADD CONSTRAINT publish_rate_overrides_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: readme_renderings readme_renderings_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.readme_renderings
    ADD CONSTRAINT readme_renderings_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.versions(id) ON DELETE CASCADE;


--
-- Name: version_owner_actions version_owner_actions_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_owner_actions
    ADD CONSTRAINT version_owner_actions_owner_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: version_owner_actions version_owner_actions_owner_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_owner_actions
    ADD CONSTRAINT version_owner_actions_owner_token_id_fkey FOREIGN KEY (api_token_id) REFERENCES public.api_tokens(id);


--
-- Name: version_owner_actions version_owner_actions_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.version_owner_actions
    ADD CONSTRAINT version_owner_actions_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.versions(id) ON DELETE CASCADE;


--
-- Name: versions_published_by versions_published_by_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions_published_by
    ADD CONSTRAINT versions_published_by_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.versions(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

