-- Your SQL goes here
CREATE SCHEMA IF NOT EXISTS discuz;

CREATE TABLE IF NOT EXISTS discuz.common_member (
	uid serial4 NOT NULL,
	email varchar(255) DEFAULT ''::character varying NOT NULL,
	username bpchar(15) DEFAULT ''::bpchar NOT NULL,
	"password" bpchar(32) DEFAULT ''::bpchar NOT NULL,
	secmobicc varchar(3) DEFAULT ''::character varying NOT NULL,
	secmobile varchar(12) DEFAULT ''::character varying NOT NULL,
	status int2 DEFAULT '0'::smallint NOT NULL,
	emailstatus int2 DEFAULT '0'::smallint NOT NULL,
	avatarstatus int2 DEFAULT '0'::smallint NOT NULL,
	secmobilestatus int2 DEFAULT '0'::smallint NOT NULL,
	videophotostatus int2 DEFAULT '0'::smallint NOT NULL,
	adminid int2 DEFAULT '0'::smallint NOT NULL,
	groupid int4 DEFAULT 0 NOT NULL,
	groupexpiry int8 DEFAULT '0'::bigint NOT NULL,
	extgroupids bpchar(20) DEFAULT ''::bpchar NOT NULL,
	regdate int8 DEFAULT '0'::bigint NOT NULL,
	credits int4 DEFAULT 0 NOT NULL,
	notifysound int2 DEFAULT '0'::smallint NOT NULL,
	timeoffset bpchar(4) DEFAULT ''::bpchar NOT NULL,
	newpm int4 DEFAULT 0 NOT NULL,
	newprompt int4 DEFAULT 0 NOT NULL,
	accessmasks int2 DEFAULT '0'::smallint NOT NULL,
	allowadmincp int2 DEFAULT '0'::smallint NOT NULL,
	onlyacceptfriendpm int2 DEFAULT '0'::smallint NOT NULL,
	conisbind int2 DEFAULT '0'::smallint NOT NULL,
	"freeze" int2 DEFAULT '0'::smallint NOT NULL,
	CONSTRAINT idx_44357_primary PRIMARY KEY (uid)
);
CREATE INDEX idx_44357_conisbind ON discuz.common_member USING btree (conisbind);
CREATE INDEX idx_44357_email ON discuz.common_member USING btree (email);
CREATE INDEX idx_44357_groupid ON discuz.common_member USING btree (groupid);
CREATE INDEX idx_44357_regdate ON discuz.common_member USING btree (regdate);
CREATE INDEX idx_44357_secmobile ON discuz.common_member USING btree (secmobile, secmobicc);
CREATE UNIQUE INDEX idx_44357_username ON discuz.common_member USING btree (username);
