# pgvector with AI Enhancements

## About

This is an enhanced version of [pgvector](https://github.com/pgvector/pgvector) with additional AI-related features for building modern RAG (Retrieval Augmented Generation) applications.

Based on pgvector v0.8.1 by [Andrew Kane](https://github.com/ankane) - the original author of pgvector.

## New AI Features

### 1. Reciprocal Rank Fusion (RRF)

Hybrid search combining vector similarity with full-text search using the industry-standard RRF algorithm.

```sql
-- Simple RRF score calculation
SELECT rrf_score(1);  -- Returns 0.0164 (1/61)

-- Hybrid search example
WITH vector_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> query_vector) AS rank FROM items
),
text_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank_cd(textsearch, plainto_tsquery(query_text)) DESC) AS rank FROM items
),
combined AS (
    SELECT id, rank FROM vector_results UNION ALL SELECT id, rank FROM text_results
)
SELECT id, SUM(rrf_score(rank)) AS rrf_score
FROM combined GROUP BY id ORDER BY rrf_score DESC;
```

### 2. Multi-vector Support

Support for late-interaction models like ColBERT and ColPali with max/sum/mean pooling.

```sql
-- Max similarity (ColBERT-style)
SELECT vector_max_sim('[3,4,5]'::vector, ARRAY['[1,2,3]'::vector, '[4,5,6]'::vector]);

-- Sum of similarities
SELECT vector_sum_sim(query, ARRAY_AGG(embedding))
FROM document_embeddings GROUP BY document_id;

-- Mean similarity
SELECT vector_mean_sim(query, candidates);
```

### 3. Sparse Vector Improvements

Enhanced sparse vector support for hybrid keyword-vector search.

```sql
-- Get number of non-zero elements
SELECT sparsevec_nnz(embedding) FROM sparse_items;

-- Store larger sparse vectors (up to 10,000 non-zeros)
INSERT INTO items VALUES ('{1:0.5, 2:0.3, ... , 10000:0.1}/10000'::sparsevec);
```

### 4. Reranking Functions

Combine multiple relevance signals and reorder results.

```sql
-- Combine scores with weights
SELECT rerank_scores(vector_scores, ARRAY[1.0, 0.5, 0.3]);

-- Reorder by combined score
SELECT * FROM rerank_order(ids, combined_scores) ORDER BY score DESC;
```

## Installation

Same as original pgvector:

```sh
cd /tmp
git clone https://github.com/yourusername/pgvector.git
cd pgvector
make
make install
```

Then in PostgreSQL:

```sql
CREATE EXTENSION vector;
```

## Documentation

For full documentation of the original pgvector features, see [README.md.orig](README.md.orig).

## Credits

- **Andrew Kane** - Original author of [pgvector](https://github.com/pgvector/pgvector)
- This enhanced version builds upon the solid foundation of pgvector

## License

Same as pgvector - Apache License 2.0

## References

- [Original pgvector GitHub](https://github.com/pgvector/pgvector)
- [RRF Paper](https://plg.uwaterloo.ca/~glittso/sigir09ir/) by F. Buttcher, C. L. A. Clarke, G. V. Cormack
- [ColBERT Paper](https://arxiv.org/abs/2110.07641) by K. Khattab, M. Zaharia