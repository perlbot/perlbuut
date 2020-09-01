BEGIN;
DROP TABLE IF EXISTS public.factoid;
CREATE TABLE public.factoid AS (SELECT * FROM sqlite.factoid);

ALTER TABLE public.factoid ALTER COLUMN original_subject TYPE text;
ALTER TABLE public.factoid ALTER COLUMN subject TYPE text;
ALTER TABLE public.factoid ALTER COLUMN copula TYPE text;
ALTER TABLE public.factoid ALTER COLUMN author TYPE text;
ALTER TABLE public.factoid ADD COLUMN namespace text;
ALTER TABLE public.factoid ADD COLUMN server text;

UPDATE public.factoid SET namespace=split_part(original_subject, E'\034', 3), server=split_part(original_subject, E'\034', 2);
UPDATE public.factoid SET namespace=NULL WHERE namespace = '';
UPDATE public.factoid SET server=NULL WHERE server = '';
UPDATE public.factoid SET original_subject=split_part(original_subject, E'\034', 4), subject=split_part(subject, E'\034', 4) WHERE namespace IS NOT NULL and server IS NOT NULL;


COMMIT;
