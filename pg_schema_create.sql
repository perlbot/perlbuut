--
-- PostgreSQL database dump
--

-- Dumped from database version 12.4 (Debian 12.4-1.pgdg100+1)
-- Dumped by pg_dump version 12.4 (Debian 12.4-1)

-- Started on 2020-09-10 18:51:24 PDT

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
-- TOC entry 8 (class 2615 OID 21278)
-- Name: sqlite; Type: SCHEMA; Schema: -; Owner: perlbot
--

CREATE SCHEMA sqlite;


ALTER SCHEMA sqlite OWNER TO perlbot;

--
-- TOC entry 2 (class 3079 OID 63457)
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- TOC entry 3003 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- TOC entry 4 (class 3079 OID 21279)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 3004 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 3 (class 3079 OID 60741)
-- Name: sqlite_fdw; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS sqlite_fdw WITH SCHEMA public;


--
-- TOC entry 3005 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION sqlite_fdw; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION sqlite_fdw IS 'SQLite Foreign Data Wrapper';


--
-- TOC entry 1740 (class 3600 OID 67153)
-- Name: english_ispell; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: perlbot
--

CREATE TEXT SEARCH DICTIONARY public.english_ispell (
    TEMPLATE = pg_catalog.ispell,
    dictfile = 'en_us', afffile = 'en_us', stopwords = 'english' );


ALTER TEXT SEARCH DICTIONARY public.english_ispell OWNER TO perlbot;

--
-- TOC entry 1763 (class 3602 OID 67132)
-- Name: factoid; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: perlbot
--

CREATE TEXT SEARCH CONFIGURATION public.factoid (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR asciiword WITH public.english_ispell, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR word WITH public.english_ispell, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR hword_part WITH public.english_ispell, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR hword_asciipart WITH public.english_ispell, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR tag WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR asciihword WITH public.english_ispell, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR hword WITH public.english_ispell, english_stem;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR uint WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.factoid
    ADD MAPPING FOR entity WITH simple;


ALTER TEXT SEARCH CONFIGURATION public.factoid OWNER TO perlbot;

--
-- TOC entry 1765 (class 1417 OID 60747)
-- Name: perlbot_factoids_server; Type: SERVER; Schema: -; Owner: postgres
--

CREATE SERVER perlbot_factoids_server FOREIGN DATA WRAPPER sqlite_fdw OPTIONS (
    database '/home/ryan/bots/perlbuut/var/factoids.db'
);


ALTER SERVER perlbot_factoids_server OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 207 (class 1259 OID 65050)
-- Name: factoid; Type: TABLE; Schema: public; Owner: perlbot
--

CREATE TABLE public.factoid (
    factoid_id bigint NOT NULL,
    original_subject text NOT NULL,
    subject text NOT NULL,
    copula text NOT NULL,
    predicate text,
    author text NOT NULL,
    modified_time bigint,
    metaphone text,
    compose_macro character(1),
    protected boolean,
    deleted boolean DEFAULT false,
    namespace text,
    server text,
    last_rendered text,
    generated_server text GENERATED ALWAYS AS (COALESCE(server, ''::text)) STORED,
    generated_namespace text GENERATED ALWAYS AS (COALESCE(namespace, ''::text)) STORED,
    full_document_tsvector tsvector GENERATED ALWAYS AS (to_tsvector('public.factoid'::regconfig, ((((original_subject || ' '::text) || copula) || ' '::text) || COALESCE(last_rendered, predicate)))) STORED
);


ALTER TABLE public.factoid OWNER TO perlbot;

--
-- TOC entry 209 (class 1259 OID 65122)
-- Name: factoid_config; Type: TABLE; Schema: public; Owner: perlbot
--

CREATE TABLE public.factoid_config (
    server text NOT NULL,
    namespace text NOT NULL,
    alias_server text,
    alias_namespace text,
    parent_server text DEFAULT ''::text NOT NULL,
    parent_namespace text DEFAULT ''::text NOT NULL,
    recursive boolean DEFAULT false,
    command_prefix text,
    generated_server text GENERATED ALWAYS AS (COALESCE(alias_server, server)) STORED,
    generated_namespace text GENERATED ALWAYS AS (COALESCE(alias_namespace, namespace)) STORED,
    notes text
);


ALTER TABLE public.factoid_config OWNER TO perlbot;

--
-- TOC entry 208 (class 1259 OID 65067)
-- Name: factoid_factoid_id_seq; Type: SEQUENCE; Schema: public; Owner: perlbot
--

CREATE SEQUENCE public.factoid_factoid_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.factoid_factoid_id_seq OWNER TO perlbot;

--
-- TOC entry 3006 (class 0 OID 0)
-- Dependencies: 208
-- Name: factoid_factoid_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: perlbot
--

ALTER SEQUENCE public.factoid_factoid_id_seq OWNED BY public.factoid.factoid_id;


--
-- TOC entry 206 (class 1259 OID 60749)
-- Name: factoid; Type: FOREIGN TABLE; Schema: sqlite; Owner: perlbot
--

CREATE FOREIGN TABLE sqlite.factoid (
    factoid_id bigint,
    original_subject character varying(100),
    subject character varying(100),
    copula character varying(25),
    predicate text,
    author character varying(100),
    modified_time bigint,
    metaphone text,
    compose_macro character(1),
    protected boolean
)
SERVER perlbot_factoids_server
OPTIONS (
    "table" 'factoid'
);
ALTER FOREIGN TABLE sqlite.factoid ALTER COLUMN factoid_id OPTIONS (
    key 'true'
);


ALTER FOREIGN TABLE sqlite.factoid OWNER TO perlbot;

--
-- TOC entry 2854 (class 2604 OID 65069)
-- Name: factoid factoid_id; Type: DEFAULT; Schema: public; Owner: perlbot
--

ALTER TABLE ONLY public.factoid ALTER COLUMN factoid_id SET DEFAULT nextval('public.factoid_factoid_id_seq'::regclass);


--
-- TOC entry 2871 (class 2606 OID 65134)
-- Name: factoid_config factoid_config_pkey; Type: CONSTRAINT; Schema: public; Owner: perlbot
--

ALTER TABLE ONLY public.factoid_config
    ADD CONSTRAINT factoid_config_pkey PRIMARY KEY (server, namespace);


--
-- TOC entry 2868 (class 2606 OID 65071)
-- Name: factoid factoid_pkey; Type: CONSTRAINT; Schema: public; Owner: perlbot
--

ALTER TABLE ONLY public.factoid
    ADD CONSTRAINT factoid_pkey PRIMARY KEY (factoid_id);


--
-- TOC entry 2869 (class 1259 OID 65138)
-- Name: factoid_config_generated_idx; Type: INDEX; Schema: public; Owner: perlbot
--

CREATE INDEX factoid_config_generated_idx ON public.factoid_config USING btree (generated_server, generated_namespace);


--
-- TOC entry 2864 (class 1259 OID 65137)
-- Name: factoid_generated_server_lookup_idx; Type: INDEX; Schema: public; Owner: perlbot
--

CREATE INDEX factoid_generated_server_lookup_idx ON public.factoid USING btree (generated_server, generated_namespace);


--
-- TOC entry 2865 (class 1259 OID 65135)
-- Name: factoid_original_subject_lookup_idx; Type: INDEX; Schema: public; Owner: perlbot
--

CREATE INDEX factoid_original_subject_lookup_idx ON public.factoid USING btree (original_subject);


--
-- TOC entry 2866 (class 1259 OID 65136)
-- Name: factoid_original_subject_trigram_idx; Type: INDEX; Schema: public; Owner: perlbot
--

CREATE INDEX factoid_original_subject_trigram_idx ON public.factoid USING gin (original_subject public.gin_trgm_ops);


-- Completed on 2020-09-10 18:51:42 PDT

--
-- PostgreSQL database dump complete
--

