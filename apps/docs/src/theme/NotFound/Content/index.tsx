import type {ReactElement} from 'react';
import Head from '@docusaurus/Head';
import Link from '@docusaurus/Link';

export default function NotFound(): ReactElement {
  return (
    <>
      <Head>
        <title>Page not found | kwatch docs</title>
        <meta name="robots" content="noindex, follow" />
      </Head>
      <main className="container kw-notfound">
        <p className="kw-notfound__code">404</p>
        <h1>That page isn't here</h1>
        <p className="kw-notfound__lead">
          The link may be old, or the page may have moved. Try search, or start
          from the top.
        </p>
        <div className="kw-notfound__links">
          <Link className="kw-primary" to="/">
            Docs home
          </Link>
          <Link to="/installation">Install kwatch</Link>
          <a href="https://kwatch.dev">kwatch.dev</a>
        </div>
      </main>
    </>
  );
}
