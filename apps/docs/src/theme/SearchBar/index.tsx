import {useEffect, useId, useMemo, useRef, useState} from 'react';
import type {ReactElement} from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';

import styles from './styles.module.css';

type SearchEntry = {
  url: string;
  title: string;
  description: string;
  headings: string[];
  content: string;
};

const stopWords = new Set(['a', 'and', 'for', 'how', 'in', 'of', 'the', 'to', 'with']);

function searchTerms(query: string): string[] {
  return query.toLocaleLowerCase().split(/\s+/)
    .map((word) => word.replace(/[^\p{L}\p{N}._-]/gu, ''))
    .filter((word) => word.length > 1 && !stopWords.has(word));
}

function scoreEntry(entry: SearchEntry, terms: string[]): number {
  const title = entry.title.toLocaleLowerCase();
  const description = entry.description.toLocaleLowerCase();
  const headings = entry.headings.join(' ').toLocaleLowerCase();
  const content = entry.content.toLocaleLowerCase();
  if (!terms.every((term) => content.includes(term) ||
    description.includes(term) || title.includes(term) || headings.includes(term))) {
    return 0;
  }
  return terms.reduce((score, term) => score +
    (title.includes(term) ? 10 : 0) +
    (headings.includes(term) ? 6 : 0) +
    (description.includes(term) ? 4 : 0) +
    (content.includes(term) ? 1 : 0), 0);
}

export default function SearchBar(): ReactElement {
  const indexUrl = useBaseUrl('/search-index.json');
  const listId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [entries, setEntries] = useState<SearchEntry[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState(false);

  // Load the index on first focus so pages stay light.
  const load = () => {
    if (entries || failed) return;
    fetch(indexUrl)
      .then((response) => {
        if (!response.ok) throw new Error('Search index unavailable');
        return response.json() as Promise<SearchEntry[]>;
      })
      .then(setEntries)
      .catch(() => setFailed(true));
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        inputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const results = useMemo(() => {
    const terms = searchTerms(query);
    if (!entries || !terms.length) return [];
    return entries
      .map((entry) => ({entry, score: scoreEntry(entry, terms)}))
      .filter((item) => item.score > 0)
      .sort((a, b) => b.score - a.score || a.entry.title.localeCompare(b.entry.title))
      .slice(0, 8)
      .map((item) => item.entry);
  }, [entries, query]);

  const showPanel = open && query.trim().length > 1;

  return (
    <div
      className={styles.search}
      onBlur={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) setOpen(false);
      }}>
      <label className={styles.label} htmlFor={`${listId}-input`}>
        Search the docs
      </label>
      <input
        id={`${listId}-input`}
        ref={inputRef}
        className={styles.input}
        type="search"
        autoComplete="off"
        placeholder="Search docs   ⌘K"
        value={query}
        aria-controls={listId}
        aria-expanded={showPanel}
        onFocus={() => {
          load();
          setOpen(true);
        }}
        onChange={(event) => {
          setQuery(event.target.value);
          setOpen(true);
        }}
        onKeyDown={(event) => {
          if (event.key === 'Escape') {
            setOpen(false);
            inputRef.current?.blur();
          }
        }}
      />
      {showPanel && (
        <ul id={listId} className={styles.panel}>
          {failed && <li className={styles.note}>Search is unavailable right now.</li>}
          {!failed && !entries && <li className={styles.note}>Loading…</li>}
          {entries && !results.length && (
            <li className={styles.note}>No pages match “{query.trim()}”.</li>
          )}
          {results.map((entry) => (
            <li key={entry.url}>
              <Link
                className={styles.result}
                to={entry.url}
                onClick={() => {
                  setOpen(false);
                  setQuery('');
                }}>
                <strong>{entry.title}</strong>
                {entry.description && <span>{entry.description}</span>}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
