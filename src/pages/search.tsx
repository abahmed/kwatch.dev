import {useEffect, useMemo, useState} from 'react';
import type {ReactElement} from 'react';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';

import styles from './search.module.css';

type SearchEntry = {
  url: string;
  type: 'Documentation' | 'Guide';
  title: string;
  description: string;
  headings: string[];
  content: string;
};

type Filter = 'All' | SearchEntry['type'];

const filters: Filter[] = ['All', 'Documentation', 'Guide'];
const suggestions = ['CrashLoopBackOff', 'Slack', 'silences', 'failover'];
const stopWords = new Set(['a', 'and', 'for', 'how', 'in', 'of', 'the', 'to', 'with']);

function searchTerms(query: string): string[] {
  return query.toLocaleLowerCase().split(/\s+/)
    .map((word) => word.replace(/[^\p{L}\p{N}._-]/gu, ''))
    .filter((word) => word.length > 1 && !stopWords.has(word));
}

function scoreEntry(entry: SearchEntry, terms: string[]): number {
  const title = entry.title.toLocaleLowerCase();
  const exactTitle = title.replace(/[^\p{L}\p{N}]/gu, '');
  const description = entry.description.toLocaleLowerCase();
  const headings = entry.headings.join(' ').toLocaleLowerCase();
  const content = entry.content.toLocaleLowerCase();
  if (!terms.every((term) => content.includes(term) ||
    description.includes(term) || title.includes(term) || headings.includes(term))) {
    return 0;
  }
  return (terms.length === 1 && exactTitle === terms[0] ? 30 : 0) +
    terms.reduce((score, term) => score +
    (title.includes(term) ? 10 : 0) +
    (headings.includes(term) ? 6 : 0) +
    (description.includes(term) ? 4 : 0) +
    (content.includes(term) ? 1 : 0), 0);
}

function excerpt(entry: SearchEntry, terms: string[]): string {
  if (terms.some((term) => entry.description.toLocaleLowerCase().includes(term))) {
    return entry.description;
  }
  const content = entry.content;
  const position = content.toLocaleLowerCase().indexOf(terms[0]);
  if (position < 0) return entry.description || content.slice(0, 180);
  const start = Math.max(0, position - 65);
  const end = Math.min(content.length, position + 165);
  return `${start ? '…' : ''}${content.slice(start, end).trim()}${end < content.length ? '…' : ''}`;
}

export default function SearchPage(): ReactElement {
  const indexUrl = useBaseUrl('/search-index.json');
  const [entries, setEntries] = useState<SearchEntry[]>([]);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<Filter>('All');
  const [state, setState] = useState<'loading' | 'ready' | 'error'>('loading');

  useEffect(() => {
    const controller = new AbortController();
    fetch(indexUrl, {signal: controller.signal})
      .then((response) => {
        if (!response.ok) throw new Error('Search index unavailable');
        return response.json() as Promise<SearchEntry[]>;
      })
      .then((data) => {
        setEntries(data);
        setState('ready');
      })
      .catch((error: unknown) => {
        if (error instanceof Error && error.name !== 'AbortError') {
          setState('error');
        }
      });
    return () => controller.abort();
  }, [indexUrl]);

  const terms = useMemo(() => searchTerms(query), [query]);
  const matches = useMemo(() => {
    if (!terms.length) return [];
    return entries
      .filter((entry) => filter === 'All' || entry.type === filter)
      .map((entry) => ({entry, score: scoreEntry(entry, terms)}))
      .filter(({score}) => score > 0)
      .sort((a, b) => b.score - a.score || a.entry.title.localeCompare(b.entry.title));
  }, [entries, filter, terms]);
  const results = matches.slice(0, 20);

  return (
    <Layout title="Search kwatch" description="Search kwatch documentation and incident response guides.">
      <Head><meta name="robots" content="noindex,follow" /></Head>
      <main className={styles.page}>
        <div className="container">
          <div className={styles.heading}>
            <p className={styles.eyebrow}>Find an answer</p>
            <h1>Search kwatch</h1>
            <p>Find setup steps, provider settings, and incident response guides.</p>
          </div>

          <label className={styles.searchLabel} htmlFor="site-search">
            Search documentation and guides
          </label>
          <div className={styles.searchBox}>
            <span aria-hidden="true">⌕</span>
            <input
              id="site-search"
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Escape') setQuery('');
              }}
              placeholder="Try CrashLoopBackOff, Slack, or failover"
              autoComplete="off"
            />
          </div>

          <div className={styles.filters} aria-label="Filter results">
            {filters.map((item) => (
              <button
                key={item}
                type="button"
                className={filter === item ? styles.activeFilter : ''}
                aria-pressed={filter === item}
                onClick={() => setFilter(item)}
              >
                {item === 'Guide' ? 'Blog guides' : item}
              </button>
            ))}
          </div>

          <div className={styles.results} aria-live="polite">
            {state === 'loading' && <p>Loading search…</p>}
            {state === 'error' && (
              <p>Search is unavailable. Browse the <Link to="/docs">documentation</Link> instead.</p>
            )}
            {state === 'ready' && !terms.length && (
              <div className={styles.suggestions}>
                <p>Popular searches</p>
                {suggestions.map((item) => (
                  <button key={item} type="button" onClick={() => setQuery(item)}>
                    {item} <span aria-hidden="true">→</span>
                  </button>
                ))}
              </div>
            )}
            {state === 'ready' && terms.length > 0 && (
              <>
                <p className={styles.count}>
                  {matches.length > results.length
                    ? `Showing ${results.length} of ${matches.length} results`
                    : matches.length
                      ? `${matches.length} matching results`
                      : 'No results found'}
                </p>
                {results.length === 0 && (
                  <p>Try a resource name, alert channel, or shorter phrase.</p>
                )}
                <div className={styles.resultList}>
                  {results.map(({entry}) => (
                    <Link key={entry.url} className={styles.result} to={entry.url}>
                      <span>{entry.type}</span>
                      <strong>{entry.title}</strong>
                      <p>{excerpt(entry, terms)}</p>
                    </Link>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>
      </main>
    </Layout>
  );
}
