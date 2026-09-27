import type {ReactNode} from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {
  HtmlClassNameProvider,
  PageMetadata,
  ThemeClassNames,
} from '@docusaurus/theme-common';
import BlogLayout from '@theme/BlogLayout';
import BlogListPaginator from '@theme/BlogListPaginator';
import BlogPostItems from '@theme/BlogPostItems';
import BlogListPageStructuredData from '@theme/BlogListPage/StructuredData';
import SearchMetadata from '@theme/SearchMetadata';
import type {Props} from '@theme/BlogListPage';

import styles from './styles.module.css';

export default function BlogListPage(props: Props): ReactNode {
  const {metadata, items, sidebar} = props;
  const {siteConfig} = useDocusaurusContext();
  const isBlogOnlyMode = metadata.permalink === '/';
  const title = isBlogOnlyMode
    ? siteConfig.title
    : metadata.blogTitle;
  const isFirstPage = metadata.permalink === '/blog';
  const currentGuides = items.filter(({content}) =>
    new Date(content.metadata.date).getFullYear() >= 2025,
  );
  const projectHistory = items.filter(({content}) =>
    new Date(content.metadata.date).getFullYear() < 2025,
  );

  return (
    <HtmlClassNameProvider
      className={clsx(
        ThemeClassNames.wrapper.blogPages,
        ThemeClassNames.page.blogListPage,
      )}
    >
      <PageMetadata title={title} description={metadata.blogDescription} />
      <SearchMetadata tag="blog_posts_list" />
      <BlogListPageStructuredData {...props} />
      <BlogLayout sidebar={sidebar}>
        {isFirstPage && (
          <header className={styles.intro}>
            <p className={styles.eyebrow}>The kwatch blog</p>
            <h1>Kubernetes incident response guides</h1>
            <p>
              Practical guides for finding causes, reducing alert noise,
              and routing Kubernetes incidents.
            </p>
            <Link to="/docs">New to kwatch? Start with the quick tour →</Link>
          </header>
        )}
        {currentGuides.length > 0 && (
          <>
            <p className={styles.listLabel}>Latest guides</p>
            <BlogPostItems items={currentGuides} />
          </>
        )}
        {projectHistory.length > 0 && (
          <section className={styles.history}>
            <p className={styles.eyebrow}>Archive</p>
            <h2>Project history</h2>
            <p>
              Earlier tutorials, milestones, and release notes are kept
              here for reference. Use the current docs for setup steps.
            </p>
            <div className={styles.historyList}>
              {projectHistory.map(({content}) => (
                <Link
                  key={content.metadata.permalink}
                  to={content.metadata.permalink}
                  className={styles.historyItem}
                >
                  <span>{new Date(content.metadata.date).getFullYear()}</span>
                  <strong>{content.metadata.title}</strong>
                  <span aria-hidden="true">→</span>
                </Link>
              ))}
            </div>
          </section>
        )}
        <BlogListPaginator metadata={metadata} />
      </BlogLayout>
    </HtmlClassNameProvider>
  );
}
