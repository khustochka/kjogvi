--
-- PostgreSQL database dump
--

\restrict hhg2TLciiGQvCurrZxVvurlp5yG6zueG2lXxL2wMR8qbLgv52aJ2JDFFs9VXIJa

-- Dumped from database version 17.6 (Debian 17.6-2.pgdg12+1)
-- Dumped by pg_dump version 18.0

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: books; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.books (
    id bigint NOT NULL,
    slug character varying(16) NOT NULL,
    version character varying(16) NOT NULL,
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
-- Name: books_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.books_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: books_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.books_id_seq OWNED BY public.books.id;


--
-- Name: ornitho_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ornitho_migrations (
    id bigint NOT NULL,
    version character varying(16) NOT NULL
);


--
-- Name: ornitho_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ornitho_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ornitho_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ornitho_migrations_id_seq OWNED BY public.ornitho_migrations.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxa (
    id bigint NOT NULL,
    book_id bigint NOT NULL,
    name_sci character varying(256) NOT NULL,
    name_en character varying(255),
    code character varying(256) NOT NULL,
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
-- Name: taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxa_id_seq OWNED BY public.taxa.id;


--
-- Name: books id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.books ALTER COLUMN id SET DEFAULT nextval('public.books_id_seq'::regclass);


--
-- Name: ornitho_migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ornitho_migrations ALTER COLUMN id SET DEFAULT nextval('public.ornitho_migrations_id_seq'::regclass);


--
-- Name: taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxa ALTER COLUMN id SET DEFAULT nextval('public.taxa_id_seq'::regclass);


--
-- Name: books books_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT books_pkey PRIMARY KEY (id);


--
-- Name: ornitho_migrations ornitho_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ornitho_migrations
    ADD CONSTRAINT ornitho_migrations_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: taxa taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxa
    ADD CONSTRAINT taxa_pkey PRIMARY KEY (id);


--
-- Name: books_slug_version_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX books_slug_version_index ON public.books USING btree (slug, version);


--
-- Name: taxa_book_id_code_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_code_index ON public.taxa USING btree (book_id, code);


--
-- Name: taxa_book_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX taxa_book_id_index ON public.taxa USING btree (book_id);


--
-- Name: taxa_book_id_name_sci_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_name_sci_index ON public.taxa USING btree (book_id, name_sci);


--
-- Name: taxa_book_id_sort_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_sort_order_index ON public.taxa USING btree (book_id, sort_order);


--
-- Name: taxa_book_id_taxon_concept_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX taxa_book_id_taxon_concept_id_index ON public.taxa USING btree (book_id, taxon_concept_id);


--
-- Name: taxa_parent_species_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX taxa_parent_species_id_index ON public.taxa USING btree (parent_species_id) WHERE (parent_species_id IS NOT NULL);


--
-- Name: taxa taxa_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxa
    ADD CONSTRAINT taxa_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(id) ON DELETE CASCADE;


--
-- Name: taxa taxa_parent_species_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxa
    ADD CONSTRAINT taxa_parent_species_id_fkey FOREIGN KEY (parent_species_id) REFERENCES public.taxa(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict hhg2TLciiGQvCurrZxVvurlp5yG6zueG2lXxL2wMR8qbLgv52aJ2JDFFs9VXIJa

INSERT INTO public."schema_migrations" (version) VALUES (20240116020356);
