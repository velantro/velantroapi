--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: v_api_session; Type: TABLE; Schema: public; Owner: fusionpbx; Tablespace: 
--

CREATE TABLE v_api_session (
    session_uuid uuid NOT NULL,
    insert_time timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE v_api_session OWNER TO fusionpbx;

--
-- PostgreSQL database dump complete
--

