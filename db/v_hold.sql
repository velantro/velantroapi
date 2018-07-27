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
-- Name: v_hold; Type: TABLE; Schema: public; Owner: fusionpbx; Tablespace: 
--

CREATE TABLE v_hold (
    channel_uuid uuid NOT NULL,
    other_channel_uuid uuid NOT NULL,
    hold_timestamp timestamp without time zone NOT NULL,
    ext text,
    domain_name text
);


ALTER TABLE v_hold OWNER TO fusionpbx;

--
-- PostgreSQL database dump complete
--

