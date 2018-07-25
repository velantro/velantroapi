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
-- Name: v_agent_break; Type: TABLE; Schema: public; Owner: fusionpbx; Tablespace: 
--

CREATE TABLE v_agent_break (
    uuid uuid NOT NULL,
    agent text NOT NULL,
    break_time_start timestamp without time zone NOT NULL,
    break_time_end timestamp without time zone
);


ALTER TABLE v_agent_break OWNER TO fusionpbx;

--
-- Name: v_agent_hold; Type: TABLE; Schema: public; Owner: fusionpbx; Tablespace: 
--

CREATE TABLE v_agent_hold (
    uuid uuid NOT NULL,
    start_stamp timestamp without time zone NOT NULL,
    milliseconds text NOT NULL,
    agent text
);


ALTER TABLE v_agent_hold OWNER TO fusionpbx;

--
-- Name: v_agent_login; Type: TABLE; Schema: public; Owner: fusionpbx; Tablespace: 
--

CREATE TABLE v_agent_login (
    uuid uuid NOT NULL,
    agent text NOT NULL,
    login_time timestamp without time zone,
    logout_time timestamp without time zone
);


ALTER TABLE v_agent_login OWNER TO fusionpbx;

--
-- PostgreSQL database dump complete
--

