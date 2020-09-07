WITH RECURSIVE factoid_lookup_order_inner (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive) AS (
  SELECT 0 AS depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive
    FROM factoid_config 
    WHERE namespace = '#perlbot' AND server = 'notfreenode.net' -- PLACEHOLDER TARGET
  UNION ALL
  SELECT p.depth+1 AS depth, m.namespace, m.server, m.alias_namespace, m.alias_server, m.parent_namespace, m.parent_server, m.recursive 
    FROM factoid_config m 
    INNER JOIN factoid_lookup_order_inner p 
      ON m.namespace = p.parent_namespace AND m.server = p.parent_server AND p.recursive
),
factoid_lookup_order (depth, namespace, server, alias_namespace, alias_server, parent_namespace, parent_server, recursive) AS (
  SELECT * FROM factoid_lookup_order_inner
  UNION ALL
  SELECT 0, '', '', NULL, NULL, NULL, NULL, false WHERE NOT EXISTS (table factoid_lookup_order_inner)
),
get_latest_factoid (depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, deleted, server, namespace) AS (
      SELECT DISTINCT ON(lo.depth) lo.depth, factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject, f.deleted, f.server, f.namespace
      FROM factoid f
      INNER JOIN factoid_lookup_order lo 
        ON COALESCE(f.server, '') = COALESCE(lo.alias_server, lo.server)
        AND COALESCE(f.namespace, '') = COALESCE(lo.alias_namespace, lo.namespace)
      WHERE original_subject = 'hi' -- PLACEHOLDER TARGET
      ORDER BY depth ASC, factoid_id DESC
)
SELECT * FROM get_latest_factoid WHERE NOT deleted ORDER BY depth ASC, factoid_id DESC;
--SELECT * FROM factoid_lookup_order;



--      SELECT factoid_id, subject, copula, predicate, author, modified_time, compose_macro, protected, original_subject
--      FROM factoid 
--      WHERE original_subject = ?
--      ORDER BY factoid_id DESC
