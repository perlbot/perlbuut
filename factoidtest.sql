WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, generated_server, generated_namespace
    FROM factoid_config 
    WHERE namespace = '#perlbot' AND server = 'freenode.net' -- PLACEHOLDER TARGET
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive, m.generated_server, m.generated_namespace 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive, gen_server, gen_namespace) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false, '', '' WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_factoid_trigram (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace, similarity) AS (
      SELECT DISTINCT ON (lo.depth, original_subject) lo.depth, factoid_id, subject, 
        copula, predicate, author, modified_time, compose_macro, protected, 
        original_subject, f.deleted, f.server, f.namespace, 
        (difference(original_subject, 'hillss') ::float + similarity('hillss', original_subject)) / greatest(length('hillss'), length(original_subject))-- PLACEHOLDER TARGET
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON f.generated_server = lo.gen_server
        AND f.generated_namespace = lo.gen_namespace
      WHERE difference(original_subject, 'hillss') ::float + similarity('hillss', original_subject) > 0.01 -- PLACEHOLDER TARGET
      ORDER BY depth ASC, original_subject ASC, factoid_id DESC
)
SELECT DISTINCT ON (similarity, original_subject) similarity, factoid_id, original_subject FROM get_factoid_trigram WHERE NOT deleted ORDER BY similarity DESC, original_subject, depth, factoid_id DESC LIMIT 10;



--      SELECT factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject
--      FROM factoid 
--      WHERE original_subject = ?
--      ORDER BY factoid_id DESC
