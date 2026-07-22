--
-- PostgreSQL database dump
--

\restrict Cy6Jk9EVeOarl1bKzePbvAkOf5vVEhYdpIhmbkziHUUWAB3Hi9t5gOT8JIrgWq3

-- Dumped from database version 18.3 (Debian 18.3-1.pgdg13+1)
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: oban; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA oban;


--
-- Name: ornithologue; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ornithologue;


--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: oban_job_state; Type: TYPE; Schema: oban; Owner: -
--

CREATE TYPE oban.oban_job_state AS ENUM (
    'available',
    'suspended',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


--
-- Name: oban_count_estimate(text, text); Type: FUNCTION; Schema: oban; Owner: -
--

CREATE FUNCTION oban.oban_count_estimate(state text, queue text) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  plan jsonb;
BEGIN
  EXECUTE 'EXPLAIN (FORMAT JSON)
           SELECT id
           FROM oban.oban_jobs
           WHERE state = $1::oban.oban_job_state
           AND queue = $2'
    INTO plan
    USING state, queue;
  RETURN plan->0->'Plan'->'Plan Rows';
END;
$_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: oban_jobs; Type: TABLE; Schema: oban; Owner: -
--

CREATE TABLE oban.oban_jobs (
    id bigint NOT NULL,
    state oban.oban_job_state DEFAULT 'available'::oban.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: oban; Owner: -
--

COMMENT ON TABLE oban.oban_jobs IS '14';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: oban; Owner: -
--

CREATE SEQUENCE oban.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: oban; Owner: -
--

ALTER SEQUENCE oban.oban_jobs_id_seq OWNED BY oban.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: oban; Owner: -
--

CREATE UNLOGGED TABLE oban.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


--
-- Name: books; Type: TABLE; Schema: ornithologue; Owner: -
--

CREATE TABLE ornithologue.books (
    id bigint NOT NULL,
    slug character varying(16) NOT NULL,
    version character varying(16) NOT NULL,
    importer character varying(255) NOT NULL,
    name character varying(256) NOT NULL,
    description text,
    publication_date date NOT NULL,
    extras jsonb DEFAULT '{}'::jsonb,
    taxa_count integer,
    imported_at timestamp without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: books_id_seq; Type: SEQUENCE; Schema: ornithologue; Owner: -
--

CREATE SEQUENCE ornithologue.books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: books_id_seq; Type: SEQUENCE OWNED BY; Schema: ornithologue; Owner: -
--

ALTER SEQUENCE ornithologue.books_id_seq OWNED BY ornithologue.books.id;


--
-- Name: ornitho_migrations; Type: TABLE; Schema: ornithologue; Owner: -
--

CREATE TABLE ornithologue.ornitho_migrations (
    id bigint NOT NULL,
    version character varying(16) NOT NULL
);


--
-- Name: ornitho_migrations_id_seq; Type: SEQUENCE; Schema: ornithologue; Owner: -
--

CREATE SEQUENCE ornithologue.ornitho_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ornitho_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: ornithologue; Owner: -
--

ALTER SEQUENCE ornithologue.ornitho_migrations_id_seq OWNED BY ornithologue.ornitho_migrations.id;


--
-- Name: taxa; Type: TABLE; Schema: ornithologue; Owner: -
--

CREATE TABLE ornithologue.taxa (
    id bigint NOT NULL,
    book_id bigint NOT NULL,
    name_sci character varying(256) NOT NULL,
    name_en character varying(255),
    code character varying(256) NOT NULL,
    codes character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    taxon_concept_id character varying(256),
    category character varying(32),
    authority character varying(255),
    authority_brackets boolean,
    protonym character varying(255),
    "order" character varying(255),
    family character varying(255),
    parent_species_id bigint,
    extras jsonb DEFAULT '{}'::jsonb,
    sort_order integer NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: taxa_id_seq; Type: SEQUENCE; Schema: ornithologue; Owner: -
--

CREATE SEQUENCE ornithologue.taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: ornithologue; Owner: -
--

ALTER SEQUENCE ornithologue.taxa_id_seq OWNED BY ornithologue.taxa.id;


--
-- Name: admin_site_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_site_settings (
    id bigint NOT NULL,
    key character varying(255) NOT NULL,
    value jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: admin_site_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_site_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_site_settings_id_seq OWNED BY public.admin_site_settings.id;


--
-- Name: admin_user_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_user_settings (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    key character varying(255) NOT NULL,
    value jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: admin_user_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_user_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_user_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_user_settings_id_seq OWNED BY public.admin_user_settings.id;


--
-- Name: checklists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklists (
    id bigint NOT NULL,
    observ_date date NOT NULL,
    location_id bigint NOT NULL,
    effort_type character varying(255),
    start_time time(0) without time zone,
    duration_minutes integer,
    distance_kms double precision,
    area_acres double precision,
    biotope character varying(255),
    weather character varying(255),
    observers character varying(255),
    notes text,
    kml_url character varying(255),
    motorless boolean DEFAULT false NOT NULL,
    legacy_autogenerated boolean DEFAULT false NOT NULL,
    resolved boolean DEFAULT true NOT NULL,
    ebird_id character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id bigint NOT NULL,
    cached_year integer GENERATED ALWAYS AS (EXTRACT(year FROM observ_date)) STORED,
    cached_month integer GENERATED ALWAYS AS (EXTRACT(month FROM observ_date)) STORED,
    import_source character varying(255),
    ebird_complete boolean,
    effort_name text
);


--
-- Name: checklists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.checklists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: checklists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.checklists_id_seq OWNED BY public.checklists.id;


--
-- Name: ebird_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ebird_locations (
    id bigint NOT NULL,
    code character varying(255) NOT NULL,
    location_type character varying(255) NOT NULL,
    country_code character varying(255),
    subnational1_code character varying(255),
    subnational2_code character varying(255),
    name character varying(255),
    location_id bigint,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: ebird_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ebird_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ebird_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ebird_locations_id_seq OWNED BY public.ebird_locations.id;


--
-- Name: ebird_user_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ebird_user_locations (
    id bigint NOT NULL,
    ebird_loc_id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    state character varying(255),
    county character varying(255),
    lat numeric,
    lon numeric,
    user_id bigint NOT NULL,
    location_id bigint,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: ebird_user_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ebird_user_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ebird_user_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ebird_user_locations_id_seq OWNED BY public.ebird_user_locations.id;


--
-- Name: image_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_observations (
    id bigint NOT NULL,
    image_id bigint NOT NULL,
    observation_id bigint NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: image_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.image_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: image_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.image_observations_id_seq OWNED BY public.image_observations.id;


--
-- Name: images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images (
    id bigint NOT NULL,
    token character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    title character varying(255),
    description text,
    sort_order integer DEFAULT 100 NOT NULL,
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    file character varying(255),
    storage_backend character varying(255) DEFAULT 'local'::character varying NOT NULL,
    user_id bigint NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    import_source character varying(255),
    legacy_url character varying(255),
    multi_species boolean DEFAULT false NOT NULL
);


--
-- Name: images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.images_id_seq OWNED BY public.images.id;


--
-- Name: import_errors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_errors (
    id bigint NOT NULL,
    category character varying(255) NOT NULL,
    submission_id character varying(255),
    rows jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    error text,
    import_log_id bigint NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: import_errors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_errors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_errors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_errors_id_seq OWNED BY public.import_errors.id;


--
-- Name: import_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_logs (
    id bigint NOT NULL,
    source character varying(255) NOT NULL,
    status character varying(255) DEFAULT 'queued'::character varying NOT NULL,
    summary jsonb DEFAULT '{}'::jsonb NOT NULL,
    error text,
    started_at timestamp without time zone,
    finished_at timestamp without time zone,
    user_id bigint NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    upload_key character varying(255),
    retried_from_id bigint
);


--
-- Name: import_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_logs_id_seq OWNED BY public.import_logs.id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id bigint NOT NULL,
    slug character varying(64) NOT NULL,
    name_en character varying(255) NOT NULL,
    location_type character varying(32) NOT NULL,
    iso_code character varying(16),
    lat numeric(8,5),
    lon numeric(8,5),
    public_index smallint,
    is_private boolean DEFAULT false NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    import_source character varying(255),
    extras jsonb DEFAULT '{}'::jsonb NOT NULL,
    user_id bigint,
    country_id bigint,
    subdivision1_id bigint,
    subdivision2_id bigint,
    city_id bigint,
    site_id bigint,
    disabled boolean DEFAULT false NOT NULL,
    hide_flag boolean DEFAULT false NOT NULL
);


--
-- Name: locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.locations_id_seq OWNED BY public.locations.id;


--
-- Name: observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observations (
    id bigint NOT NULL,
    checklist_id bigint NOT NULL,
    taxon_key character varying(255) NOT NULL,
    quantity character varying(255),
    voice boolean DEFAULT false NOT NULL,
    notes text,
    private_notes text,
    unreported boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    ebird_obs_id character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    import_source character varying(255),
    breeding_code character varying(255),
    ml_catalog_numbers character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL
);


--
-- Name: observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observations_id_seq OWNED BY public.observations.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: special_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.special_locations (
    id bigint NOT NULL,
    parent_location_id bigint NOT NULL,
    child_location_id bigint NOT NULL
);


--
-- Name: special_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.special_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: special_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.special_locations_id_seq OWNED BY public.special_locations.id;


--
-- Name: species_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.species_pages (
    id bigint NOT NULL,
    name_sci character varying(255) NOT NULL,
    common_name character varying(255),
    name_en character varying(255),
    "order" character varying(255),
    family character varying(255),
    extras jsonb DEFAULT '{}'::jsonb,
    sort_order integer NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: species_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.species_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: species_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.species_pages_id_seq OWNED BY public.species_pages.id;


--
-- Name: species_taxa_mappings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.species_taxa_mappings (
    id bigint NOT NULL,
    species_page_id bigint NOT NULL,
    taxon_key character varying(255) NOT NULL,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: species_taxa_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.species_taxa_mappings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: species_taxa_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.species_taxa_mappings_id_seq OWNED BY public.species_taxa_mappings.id;


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ebird jsonb,
    logbook_settings jsonb DEFAULT '[]'::jsonb,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_preferences_id_seq OWNED BY public.user_preferences.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    about text,
    country character varying(255),
    ebird_profile_url character varying(255),
    website_url character varying(255),
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    avatar character varying(255),
    avatar_storage_backend character varying(255)
);


--
-- Name: user_profiles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profiles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profiles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profiles_id_seq OWNED BY public.user_profiles.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255) NOT NULL,
    roles character varying(255)[] DEFAULT ARRAY[]::character varying[] NOT NULL,
    extras jsonb DEFAULT '{}'::jsonb,
    confirmed_at timestamp without time zone,
    inserted_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    default_book_signature character varying(255),
    public_token character varying(255) NOT NULL,
    nickname character varying(255) NOT NULL,
    display_name character varying(255)
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
-- Name: users_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    inserted_at timestamp without time zone NOT NULL
);


--
-- Name: users_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_tokens_id_seq OWNED BY public.users_tokens.id;


--
-- Name: oban_jobs id; Type: DEFAULT; Schema: oban; Owner: -
--

ALTER TABLE ONLY oban.oban_jobs ALTER COLUMN id SET DEFAULT nextval('oban.oban_jobs_id_seq'::regclass);


--
-- Name: books id; Type: DEFAULT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.books ALTER COLUMN id SET DEFAULT nextval('ornithologue.books_id_seq'::regclass);


--
-- Name: ornitho_migrations id; Type: DEFAULT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.ornitho_migrations ALTER COLUMN id SET DEFAULT nextval('ornithologue.ornitho_migrations_id_seq'::regclass);


--
-- Name: taxa id; Type: DEFAULT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.taxa ALTER COLUMN id SET DEFAULT nextval('ornithologue.taxa_id_seq'::regclass);


--
-- Name: admin_site_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_site_settings ALTER COLUMN id SET DEFAULT nextval('public.admin_site_settings_id_seq'::regclass);


--
-- Name: admin_user_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_settings ALTER COLUMN id SET DEFAULT nextval('public.admin_user_settings_id_seq'::regclass);


--
-- Name: checklists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklists ALTER COLUMN id SET DEFAULT nextval('public.checklists_id_seq'::regclass);


--
-- Name: ebird_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_locations ALTER COLUMN id SET DEFAULT nextval('public.ebird_locations_id_seq'::regclass);


--
-- Name: ebird_user_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_user_locations ALTER COLUMN id SET DEFAULT nextval('public.ebird_user_locations_id_seq'::regclass);


--
-- Name: image_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_observations ALTER COLUMN id SET DEFAULT nextval('public.image_observations_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images ALTER COLUMN id SET DEFAULT nextval('public.images_id_seq'::regclass);


--
-- Name: import_errors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_errors ALTER COLUMN id SET DEFAULT nextval('public.import_errors_id_seq'::regclass);


--
-- Name: import_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_logs ALTER COLUMN id SET DEFAULT nextval('public.import_logs_id_seq'::regclass);


--
-- Name: locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations ALTER COLUMN id SET DEFAULT nextval('public.locations_id_seq'::regclass);


--
-- Name: observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observations ALTER COLUMN id SET DEFAULT nextval('public.observations_id_seq'::regclass);


--
-- Name: special_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_locations ALTER COLUMN id SET DEFAULT nextval('public.special_locations_id_seq'::regclass);


--
-- Name: species_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.species_pages ALTER COLUMN id SET DEFAULT nextval('public.species_pages_id_seq'::regclass);


--
-- Name: species_taxa_mappings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.species_taxa_mappings ALTER COLUMN id SET DEFAULT nextval('public.species_taxa_mappings_id_seq'::regclass);


--
-- Name: user_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences ALTER COLUMN id SET DEFAULT nextval('public.user_preferences_id_seq'::regclass);


--
-- Name: user_profiles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles ALTER COLUMN id SET DEFAULT nextval('public.user_profiles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: users_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens ALTER COLUMN id SET DEFAULT nextval('public.users_tokens_id_seq'::regclass);


--
-- Name: oban_jobs non_negative_priority; Type: CHECK CONSTRAINT; Schema: oban; Owner: -
--

ALTER TABLE oban.oban_jobs
    ADD CONSTRAINT non_negative_priority CHECK ((priority >= 0)) NOT VALID;


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: oban; Owner: -
--

ALTER TABLE ONLY oban.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: oban; Owner: -
--

ALTER TABLE ONLY oban.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (id);


--
-- Name: ornitho_migrations ornitho_migrations_pkey; Type: CONSTRAINT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.ornitho_migrations
    ADD CONSTRAINT ornitho_migrations_pkey PRIMARY KEY (id);


--
-- Name: taxa taxa_pkey; Type: CONSTRAINT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.taxa
    ADD CONSTRAINT taxa_pkey PRIMARY KEY (id);


--
-- Name: admin_site_settings admin_site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_site_settings
    ADD CONSTRAINT admin_site_settings_pkey PRIMARY KEY (id);


--
-- Name: admin_user_settings admin_user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_settings
    ADD CONSTRAINT admin_user_settings_pkey PRIMARY KEY (id);


--
-- Name: checklists checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (id);


--
-- Name: ebird_locations ebird_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_locations
    ADD CONSTRAINT ebird_locations_pkey PRIMARY KEY (id);


--
-- Name: ebird_user_locations ebird_user_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_user_locations
    ADD CONSTRAINT ebird_user_locations_pkey PRIMARY KEY (id);


--
-- Name: image_observations image_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_observations
    ADD CONSTRAINT image_observations_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: import_errors import_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_errors
    ADD CONSTRAINT import_errors_pkey PRIMARY KEY (id);


--
-- Name: import_logs import_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_logs
    ADD CONSTRAINT import_logs_pkey PRIMARY KEY (id);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: observations observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observations
    ADD CONSTRAINT observations_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: special_locations special_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_locations
    ADD CONSTRAINT special_locations_pkey PRIMARY KEY (id);


--
-- Name: species_pages species_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.species_pages
    ADD CONSTRAINT species_pages_pkey PRIMARY KEY (id);


--
-- Name: species_taxa_mappings species_taxa_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.species_taxa_mappings
    ADD CONSTRAINT species_taxa_mappings_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: oban; Owner: -
--

CREATE INDEX oban_jobs_args_index ON oban.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: oban; Owner: -
--

CREATE INDEX oban_jobs_meta_index ON oban.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_cancelled_at_index; Type: INDEX; Schema: oban; Owner: -
--

CREATE INDEX oban_jobs_state_cancelled_at_index ON oban.oban_jobs USING btree (state, cancelled_at);


--
-- Name: oban_jobs_state_discarded_at_index; Type: INDEX; Schema: oban; Owner: -
--

CREATE INDEX oban_jobs_state_discarded_at_index ON oban.oban_jobs USING btree (state, discarded_at);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: oban; Owner: -
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON oban.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: books_slug_version_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE UNIQUE INDEX books_slug_version_index ON ornithologue.books USING btree (slug, version);


--
-- Name: taxa_book_id_code_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_code_index ON ornithologue.taxa USING btree (book_id, code);


--
-- Name: taxa_book_id_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE INDEX taxa_book_id_index ON ornithologue.taxa USING btree (book_id);


--
-- Name: taxa_book_id_name_sci_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_name_sci_index ON ornithologue.taxa USING btree (book_id, name_sci);


--
-- Name: taxa_book_id_sort_order_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_sort_order_index ON ornithologue.taxa USING btree (book_id, sort_order);


--
-- Name: taxa_book_id_taxon_concept_id_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_taxon_concept_id_index ON ornithologue.taxa USING btree (book_id, taxon_concept_id);


--
-- Name: taxa_codes_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE INDEX taxa_codes_index ON ornithologue.taxa USING gin (codes);


--
-- Name: taxa_parent_species_id_index; Type: INDEX; Schema: ornithologue; Owner: -
--

CREATE INDEX taxa_parent_species_id_index ON ornithologue.taxa USING btree (parent_species_id) WHERE (parent_species_id IS NOT NULL);


--
-- Name: admin_site_settings_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admin_site_settings_key_index ON public.admin_site_settings USING btree (key);


--
-- Name: admin_user_settings_user_id_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admin_user_settings_user_id_key_index ON public.admin_user_settings USING btree (user_id, key);


--
-- Name: checklists_cached_month_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklists_cached_month_index ON public.checklists USING btree (cached_month);


--
-- Name: checklists_cached_year_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklists_cached_year_index ON public.checklists USING btree (cached_year);


--
-- Name: checklists_ebird_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX checklists_ebird_id_index ON public.checklists USING btree (ebird_id) WHERE (ebird_id IS NOT NULL);


--
-- Name: checklists_location_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklists_location_id_index ON public.checklists USING btree (location_id);


--
-- Name: checklists_observ_date_location_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklists_observ_date_location_id_index ON public.checklists USING btree (observ_date, location_id);


--
-- Name: checklists_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX checklists_user_id_index ON public.checklists USING btree (user_id);


--
-- Name: ebird_locations_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ebird_locations_code_index ON public.ebird_locations USING btree (code);


--
-- Name: ebird_locations_country_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ebird_locations_country_code_index ON public.ebird_locations USING btree (country_code);


--
-- Name: ebird_locations_location_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ebird_locations_location_id_index ON public.ebird_locations USING btree (location_id);


--
-- Name: ebird_locations_subnational1_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ebird_locations_subnational1_code_index ON public.ebird_locations USING btree (subnational1_code);


--
-- Name: ebird_user_locations_location_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ebird_user_locations_location_id_index ON public.ebird_user_locations USING btree (location_id);


--
-- Name: ebird_user_locations_user_id_ebird_loc_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ebird_user_locations_user_id_ebird_loc_id_index ON public.ebird_user_locations USING btree (user_id, ebird_loc_id);


--
-- Name: image_observations_image_id_observation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX image_observations_image_id_observation_id_index ON public.image_observations USING btree (image_id, observation_id);


--
-- Name: image_observations_observation_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX image_observations_observation_id_index ON public.image_observations USING btree (observation_id);


--
-- Name: images_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX images_token_index ON public.images USING btree (token);


--
-- Name: images_user_id_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX images_user_id_slug_index ON public.images USING btree (user_id, slug);


--
-- Name: import_errors_import_log_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX import_errors_import_log_id_index ON public.import_errors USING btree (import_log_id);


--
-- Name: import_logs_retried_from_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX import_logs_retried_from_id_index ON public.import_logs USING btree (retried_from_id);


--
-- Name: import_logs_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX import_logs_user_id_index ON public.import_logs USING btree (user_id);


--
-- Name: locations_city_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_city_id_index ON public.locations USING btree (city_id);


--
-- Name: locations_common_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX locations_common_slug_index ON public.locations USING btree (slug) WHERE (user_id IS NULL);


--
-- Name: locations_country_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_country_id_index ON public.locations USING btree (country_id);


--
-- Name: locations_iso_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX locations_iso_code_index ON public.locations USING btree (iso_code) WHERE (iso_code IS NOT NULL);


--
-- Name: locations_location_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_location_type_index ON public.locations USING btree (location_type);


--
-- Name: locations_site_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_site_id_index ON public.locations USING btree (site_id);


--
-- Name: locations_subdivision1_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_subdivision1_id_index ON public.locations USING btree (subdivision1_id);


--
-- Name: locations_subdivision2_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_subdivision2_id_index ON public.locations USING btree (subdivision2_id);


--
-- Name: locations_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX locations_user_id_index ON public.locations USING btree (user_id);


--
-- Name: locations_user_id_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX locations_user_id_slug_index ON public.locations USING btree (user_id, slug);


--
-- Name: observations_checklist_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX observations_checklist_id_index ON public.observations USING btree (checklist_id);


--
-- Name: observations_taxon_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX observations_taxon_key_index ON public.observations USING btree (taxon_key);


--
-- Name: special_locations_parent_location_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX special_locations_parent_location_id_index ON public.special_locations USING btree (parent_location_id);


--
-- Name: species_pages_name_sci_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX species_pages_name_sci_index ON public.species_pages USING btree (name_sci);


--
-- Name: species_pages_sort_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX species_pages_sort_order_index ON public.species_pages USING btree (sort_order);


--
-- Name: species_taxa_mappings_species_page_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX species_taxa_mappings_species_page_id_index ON public.species_taxa_mappings USING btree (species_page_id);


--
-- Name: species_taxa_mappings_taxon_key_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX species_taxa_mappings_taxon_key_index ON public.species_taxa_mappings USING btree (taxon_key);


--
-- Name: user_preferences_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_preferences_user_id_index ON public.user_preferences USING btree (user_id);


--
-- Name: user_profiles_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_profiles_user_id_index ON public.user_profiles USING btree (user_id);


--
-- Name: users_default_book_signature_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_default_book_signature_index ON public.users USING btree (default_book_signature);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users USING btree (email);


--
-- Name: users_nickname_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_nickname_index ON public.users USING btree (nickname);


--
-- Name: users_public_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_public_token_index ON public.users USING btree (public_token);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens USING btree (user_id);


--
-- Name: taxa taxa_book_id_fkey; Type: FK CONSTRAINT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.taxa
    ADD CONSTRAINT taxa_book_id_fkey FOREIGN KEY (book_id) REFERENCES ornithologue.books(id) ON DELETE CASCADE;


--
-- Name: taxa taxa_parent_species_id_fkey; Type: FK CONSTRAINT; Schema: ornithologue; Owner: -
--

ALTER TABLE ONLY ornithologue.taxa
    ADD CONSTRAINT taxa_parent_species_id_fkey FOREIGN KEY (parent_species_id) REFERENCES ornithologue.taxa(id) ON DELETE SET NULL;


--
-- Name: admin_user_settings admin_user_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_settings
    ADD CONSTRAINT admin_user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: checklists checklists_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklists
    ADD CONSTRAINT checklists_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: checklists checklists_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklists
    ADD CONSTRAINT checklists_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: ebird_locations ebird_locations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_locations
    ADD CONSTRAINT ebird_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL DEFERRABLE;


--
-- Name: ebird_user_locations ebird_user_locations_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_user_locations
    ADD CONSTRAINT ebird_user_locations_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;


--
-- Name: ebird_user_locations ebird_user_locations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ebird_user_locations
    ADD CONSTRAINT ebird_user_locations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: image_observations image_observations_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_observations
    ADD CONSTRAINT image_observations_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id) ON DELETE CASCADE;


--
-- Name: image_observations image_observations_observation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_observations
    ADD CONSTRAINT image_observations_observation_id_fkey FOREIGN KEY (observation_id) REFERENCES public.observations(id) ON DELETE CASCADE;


--
-- Name: images images_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: import_errors import_errors_import_log_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_errors
    ADD CONSTRAINT import_errors_import_log_id_fkey FOREIGN KEY (import_log_id) REFERENCES public.import_logs(id) ON DELETE CASCADE;


--
-- Name: import_logs import_logs_retried_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_logs
    ADD CONSTRAINT import_logs_retried_from_id_fkey FOREIGN KEY (retried_from_id) REFERENCES public.import_logs(id) ON DELETE SET NULL;


--
-- Name: import_logs import_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_logs
    ADD CONSTRAINT import_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: locations locations_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.locations(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: locations locations_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.locations(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: locations locations_site_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_site_id_fkey FOREIGN KEY (site_id) REFERENCES public.locations(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: locations locations_subdivision1_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_subdivision1_id_fkey FOREIGN KEY (subdivision1_id) REFERENCES public.locations(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: locations locations_subdivision2_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_subdivision2_id_fkey FOREIGN KEY (subdivision2_id) REFERENCES public.locations(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: locations locations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: observations observations_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observations
    ADD CONSTRAINT observations_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES public.checklists(id) ON DELETE RESTRICT;


--
-- Name: special_locations special_locations_child_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_locations
    ADD CONSTRAINT special_locations_child_location_id_fkey FOREIGN KEY (child_location_id) REFERENCES public.locations(id) ON DELETE CASCADE DEFERRABLE;


--
-- Name: special_locations special_locations_parent_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_locations
    ADD CONSTRAINT special_locations_parent_location_id_fkey FOREIGN KEY (parent_location_id) REFERENCES public.locations(id) ON DELETE CASCADE;


--
-- Name: species_taxa_mappings species_taxa_mappings_species_page_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.species_taxa_mappings
    ADD CONSTRAINT species_taxa_mappings_species_page_id_fkey FOREIGN KEY (species_page_id) REFERENCES public.species_pages(id) ON DELETE RESTRICT;


--
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_profiles user_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users_tokens users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict Cy6Jk9EVeOarl1bKzePbvAkOf5vVEhYdpIhmbkziHUUWAB3Hi9t5gOT8JIrgWq3

INSERT INTO public."schema_migrations" (version) VALUES (20231216191458);
INSERT INTO public."schema_migrations" (version) VALUES (20231224012458);
INSERT INTO public."schema_migrations" (version) VALUES (20240120044005);
INSERT INTO public."schema_migrations" (version) VALUES (20240627032425);
INSERT INTO public."schema_migrations" (version) VALUES (20251013044023);
INSERT INTO public."schema_migrations" (version) VALUES (20251015130047);
INSERT INTO public."schema_migrations" (version) VALUES (20260115190000);
INSERT INTO public."schema_migrations" (version) VALUES (20260410000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260419120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260419183659);
INSERT INTO public."schema_migrations" (version) VALUES (20260508013050);
INSERT INTO public."schema_migrations" (version) VALUES (20260509232720);
INSERT INTO public."schema_migrations" (version) VALUES (20260603121159);
INSERT INTO public."schema_migrations" (version) VALUES (20260603220042);
INSERT INTO public."schema_migrations" (version) VALUES (20260606192436);
INSERT INTO public."schema_migrations" (version) VALUES (20260607195437);
INSERT INTO public."schema_migrations" (version) VALUES (20260608025435);
INSERT INTO public."schema_migrations" (version) VALUES (20260612000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260613120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260615170413);
INSERT INTO public."schema_migrations" (version) VALUES (20260618000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260618000100);
INSERT INTO public."schema_migrations" (version) VALUES (20260618184652);
INSERT INTO public."schema_migrations" (version) VALUES (20260619120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260620000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260620120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260621120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260623000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260623120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260623130000);
INSERT INTO public."schema_migrations" (version) VALUES (20260625120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260625130000);
INSERT INTO public."schema_migrations" (version) VALUES (20260626171732);
INSERT INTO public."schema_migrations" (version) VALUES (20260629230000);
INSERT INTO public."schema_migrations" (version) VALUES (20260707180000);
INSERT INTO public."schema_migrations" (version) VALUES (20260708000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260708000001);
INSERT INTO public."schema_migrations" (version) VALUES (20260709000000);
INSERT INTO public."schema_migrations" (version) VALUES (20260713101232);
INSERT INTO public."schema_migrations" (version) VALUES (20260713120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260716120000);
INSERT INTO public."schema_migrations" (version) VALUES (20260716232748);
INSERT INTO public."schema_migrations" (version) VALUES (20260719043002);
INSERT INTO public."schema_migrations" (version) VALUES (20260719044909);
INSERT INTO public."schema_migrations" (version) VALUES (20260719191706);
INSERT INTO public."schema_migrations" (version) VALUES (20260720051106);
INSERT INTO public."schema_migrations" (version) VALUES (20260720204431);
INSERT INTO public."schema_migrations" (version) VALUES (20260721035446);
INSERT INTO public."schema_migrations" (version) VALUES (20260722215520);
INSERT INTO public."schema_migrations" (version) VALUES (20260722221701);
INSERT INTO public."schema_migrations" (version) VALUES (20260722230903);
