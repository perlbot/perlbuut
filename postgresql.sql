CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

BEGIN;
DROP TABLE IF EXISTS public.factoid;
CREATE TABLE public.factoid AS (SELECT * FROM sqlite.factoid);

CREATE SEQUENCE IF NOT EXISTS factoid_factoid_id_seq AS bigint OWNED BY public.factoid.factoid_id;
SELECT setval('factoid_factoid_id_seq', (select max(factoid_id)+1 from public.factoid));
ALTER TABLE public.factoid ALTER COLUMN factoid_id SET DEFAULT nextval('factoid_factoid_id_seq');
ALTER TABLE public.factoid ALTER COLUMN factoid_id SET NOT NULL;
ALTER TABLE public.factoid ADD PRIMARY KEY (factoid_id);

ALTER TABLE public.factoid ALTER COLUMN original_subject TYPE text;
ALTER TABLE public.factoid ALTER COLUMN original_subject SET NOT NULL;
ALTER TABLE public.factoid ALTER COLUMN subject TYPE text;
ALTER TABLE public.factoid ALTER COLUMN subject SET NOT NULL;
ALTER TABLE public.factoid ALTER COLUMN copula TYPE text;
ALTER TABLE public.factoid ALTER COLUMN copula SET NOT NULL;
ALTER TABLE public.factoid ALTER COLUMN author TYPE text;
ALTER TABLE public.factoid ALTER COLUMN author SET NOT NULL;
ALTER TABLE public.factoid ADD COLUMN deleted boolean DEFAULT false;
ALTER TABLE public.factoid ADD COLUMN namespace text;
ALTER TABLE public.factoid ADD COLUMN server text;
ALTER TABLE public.factoid ADD COLUMN last_rendered text;
-- this actually lets me use a multi-column index that cuts the cost in half.
ALTER TABLE public.factoid ADD COLUMN generated_server text GENERATED ALWAYS AS (COALESCE(server, '')) STORED;
ALTER TABLE public.factoid ADD COLUMN generated_namespace text GENERATED ALWAYS AS (COALESCE(namespace, '')) STORED;

UPDATE public.factoid SET namespace=split_part(original_subject, E'\034', 3), server=split_part(original_subject, E'\034', 2);
UPDATE public.factoid SET namespace=NULL WHERE namespace = '';
UPDATE public.factoid SET server=NULL WHERE server = '';
UPDATE public.factoid SET original_subject=split_part(original_subject, E'\034', 4), subject=split_part(subject, E'\034', 4) WHERE namespace IS NOT NULL and server IS NOT NULL;
UPDATE public.factoid SET last_rendered = predicate; -- just copy macros as the last rendered, keeps old behavior until i code up the storage

DROP TABLE IF EXISTS public.factoid_namespace_config;
DROP TABLE IF EXISTS public.factoid_config;
CREATE TABLE public.factoid_config (
   server text NOT NULL,
   namespace text NOT NULL,

-- this lets me set the explicit name used in the rest of the database
   alias_server text,
   alias_namespace text,
-- this lets me set the explicit name for the parent namespace, this only refers to the server+namespace values, not the alias_* they set
   parent_server text NOT NULL DEFAULT '',
   parent_namespace text NOT NULL DEFAULT '',
-- Should we do the recursive lookup into the parent_*, this is needed because NULL is a valid value for parent_*
   recursive boolean DEFAULT false,
   command_prefix text,
   generated_server text GENERATED ALWAYS AS (COALESCE(alias_server, server)) STORED,
   generated_namespace text GENERATED ALWAYS AS (COALESCE(alias_namespace, namespace)) STORED,

   PRIMARY KEY (server, namespace)
);

INSERT INTO public.factoid_config (server, namespace, alias_server, alias_namespace, recursive, command_prefix) 
     VALUES ('freenode.net', '#perlbot', 'freenode.net', '#perlbot', true,  NULL),
            ('',             '',         '',             '',         false, NULL), -- the parent of all
            ('freenode.net', '#regex',   'freenode.net', '#regex',   false, '!'),
            ('freenode.net', '#regexen', 'freenode.net', '#regex',   false, '!');

CREATE INDEX IF NOT EXISTS factoid_original_subject_lookup_idx ON public.factoid (original_subject);
CREATE INDEX IF NOT EXISTS factoid_original_subject_trigram_idx ON public.factoid USING GIN(original_subject gin_trgm_ops);
CREATE INDEX IF NOT EXISTS factoid_generated_server_lookup_idx ON public.factoid (generated_server, generated_namespace);
CREATE INDEX IF NOT EXISTS factoid_config_generated_idx ON public.factoid_config (generated_server, generated_namespace);

COMMIT;
