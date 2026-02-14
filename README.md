# pgvector-ai

> AI-enhanced PostgreSQL vector similarity search extension

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13+-blue.svg)](https://www.postgresql.org)
[![pgvector Version](https://img.shields.io/badge/pgvector-0.8.1-orange)](https://github.com/pgvector/pgvector)

## Overview

pgvector-ai is an enhanced PostgreSQL extension that extends [pgvector](https://github.com/pgvector/pgvector) with advanced AI capabilities for building modern retrieval augmented generation (RAG) applications. This extension provides essential tools for hybrid search, multi-vector operations, and result reranking that are critical for production-quality AI applications.

This project builds upon the solid foundation of pgvector v0.8.1 by Andrew Kane, adding features specifically designed to address common challenges in AI-powered search and retrieval systems.

## Status

**Work in Progress**

This extension is actively being developed. While the core features are functional, expect APIs and behavior to evolve. Feedback and contributions are welcome.

## Why pgvector-ai?

Building AI-powered search applications with PostgreSQL requires more than just vector storage. pgvector-ai addresses several key challenges:

### Hybrid Search

Combine vector similarity search with full-text search using Reciprocal Rank Fusion (RRF), the industry-standard algorithm for fusing ranked result lists from multiple retrieval methods.

### Late-Interaction Models

Support for ColBERT, ColPali, and other late-interaction embedding models that produce multiple vectors per document, enabling more nuanced similarity computation.

### Result Reranking

Combine multiple relevance signals (vector distance, popularity, recency, keyword relevance) to improve result quality beyond the initial retrieval stage.

## Installation

### Prerequisites

- PostgreSQL 13+
- C compiler (gcc or clang)
- PostgreSQL server development headers

### Build from Source

```bash
git clone https://github.com/cbuntingde/pgvector-ai.git
cd pgvector-ai
make
make install
```

### Docker

```bash
docker build -t pgvector-ai:latest .
docker run -d --name pgvector-ai -e POSTGRES_PASSWORD=postgres pgvector-ai:latest
```

### Enable Extension

```sql
CREATE EXTENSION vector;
```

## Quick Start

### Hybrid Search with RRF

Combine vector similarity with full-text search:

```sql
-- Create sample table with vectors and text
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding VECTOR(384),
    textsearch TSVECTOR
);

-- Insert sample data
INSERT INTO documents (content, embedding, textsearch) VALUES
    ('Machine learning fundamentals', '[0.1, 0.2, 0.3]'::vector(384), 
     to_tsvector('Machine learning fundamentals')),
    ('Deep neural networks explained', '[0.2, 0.3, 0.4]'::vector(384), 
     to_tsvector('Deep neural networks explained'));

-- Hybrid search combining vector and text results
WITH vector_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> query_vector) AS rank
    FROM documents
),
text_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank_cd(textsearch, query_tsquery) DESC) AS rank
    FROM documents
    WHERE textsearch @@ query_tsquery
),
combined AS (
    SELECT id, rank FROM vector_results
    UNION ALL
    SELECT id, rank FROM text_results
)
SELECT id, SUM(rrf_score(rank)) AS rrf_score
FROM combined
GROUP BY id
ORDER BY rrf_score DESC
LIMIT 10;
```

### Multi-Vector Operations (ColBERT-style)

```sql
-- Store document embeddings in a separate table for multi-vector models
CREATE TABLE doc_embeddings (
    document_id BIGINT REFERENCES documents(id),
    embedding VECTOR(128),
    position INT
);

-- Max similarity (ColBERT-style)
SELECT document_id,
       vector_max_sim(query_vector, ARRAY_AGG(embedding)) AS max_sim
FROM doc_embeddings
GROUP BY document_id
ORDER BY max_sim DESC;

-- Sum of similarities
SELECT document_id,
       vector_sum_sim(query_vector, ARRAY_AGG(embedding)) AS sum_sim
FROM doc_embeddings
GROUP BY document_id
ORDER BY sum_sim DESC;
```

### Sparse Vector Operations

```sql
-- Get number of non-zero elements in sparse vector
SELECT sparsevec_nnz(embedding) FROM sparse_documents;

-- Hybrid keyword-vector search with sparse representations
SELECT id, content,
       embedding <=> query_vector AS distance,
       ts_rank_cd(textsearch, query_tsquery) AS text_rank
FROM documents
ORDER BY distance, text_rank
LIMIT 10;
```

### Result Reranking

```sql
-- Combine multiple relevance signals with weights
WITH initial_results AS (
    SELECT id, content,
           vector_score,
           popularity_score,
           recency_score
    FROM documents
    WHERE ...
)
SELECT id, content,
       rerank_scores(
           ARRAY[vector_score, popularity_score, recency_score],
           ARRAY[1.0, 0.5, 0.3]
       ) AS weighted_scores
FROM initial_results
ORDER BY weighted_scores[1] DESC;
```

## API Reference

### RRF Functions

| Function | Description |
|----------|-------------|
| `rrf_score(rank int, k float8 DEFAULT 60)` | Calculate RRF score for a single rank |
| `rrf_score(rank bigint, k float8 DEFAULT 60)` | Bigint version for large result sets |

### Multi-Vector Functions

| Function | Description |
|----------|-------------|
| `vector_max_sim(query vector, candidates vector[])` | Maximum cosine similarity (ColBERT-style) |
| `vector_sum_sim(query vector, candidates vector[])` | Sum of cosine similarities |
| `vector_mean_sim(query vector, candidates vector[])` | Mean of cosine similarities |

### Sparse Vector Functions

| Function | Description |
|----------|-------------|
| `sparsevec_nnz(sparsevec)` | Count non-zero elements |

### Reranking Functions

| Function | Description |
|----------|-------------|
| `rerank_scores(scores float8[], weights float8[])` | Combine scores with weights |
| `rerank_order(ids bigint[], scores float8[])` | Reorder results by score |

## Directory Structure

```
pgvector-ai/
├── src/                    # C source code
│   ├── vector.c           # Core vector operations
│   ├── sparsevec.c        # Sparse vector functions
│   ├── hnsw.c/.h          # HNSW index implementation
│   └── ivfflat.c/.h       # IVFFlat index implementation
├── sql/                   # SQL definitions
│   └── vector.sql         # All SQL functions and types
├── test/                  # Test files
│   ├── sql/               # SQL regression tests
│   │   ├── rrf.sql
│   │   ├── rrf_hybrid.sql
│   │   └── ai_features_test.sql
│   └── t/                 # TAP tests
├── Dockerfile            # Docker image definition
├── Makefile              # Build configuration
├── LICENSE               # Apache 2.0 License
└── README.md             # This file
```

## Dependencies

- **pgvector** (v0.8.1) - Base vector extension by Andrew Kane
- **PostgreSQL** 13+ - Database server

For LLM-based reranking, consider using [pgai](https://github.com/timescale/pgai) alongside this extension.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

- **Andrew Kane** - Original author of [pgvector](https://github.com/pgvector/pgvector)
- **Reciprocal Rank Fusion** - Algorithm by Buttcher, Clarke, and Cormack
- **ColBERT** - Late-interaction model by Khattab and Zaharia

## License

Licensed under the Apache License, Version 2.0 (see [LICENSE](LICENSE)).

---

Built by Chris Bunting &lt;cbuntingde@gmail.com&gt;