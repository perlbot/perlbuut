BEGIN;
DROP TABLE IF EXISTS public.factoid;
CREATE TABLE public.factoid AS (SELECT * FROM sqlite.factoid);

ALTER TABLE public.factoid ALTER COLUMN original_subject TYPE text;
ALTER TABLE public.factoid ALTER COLUMN subject TYPE text;
ALTER TABLE public.factoid ALTER COLUMN copula TYPE text;
ALTER TABLE public.factoid ALTER COLUMN author TYPE text;
ALTER TABLE public.factoid ADD COLUMN deleted boolean DEFAULT false;
ALTER TABLE public.factoid ADD COLUMN namespace text;
ALTER TABLE public.factoid ADD COLUMN server text;
ALTER TABLE public.factoid ADD COLUMN last_rendered text;

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

   CONSTRAINT unique_config UNIQUE (server, namespace)
);

INSERT INTO public.factoid_config (server, namespace, alias_server, alias_namespace, recursive, command_prefix) 
     VALUES ('freenode.net', '#perlbot', 'freenode.net', '#perlbot', true,  NULL),
            ('',             '',         '',             '',         false, NULL), -- the parent of all
            ('freenode.net', '#regex',   'freenode.net', '#regex',   false, '!'),
            ('freenode.net', '#regexen', 'freenode.net', '#regex',   false, '!');

COMMIT;
