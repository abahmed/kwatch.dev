import React from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import useBaseUrl from "@docusaurus/useBaseUrl";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";

import styles from "./styles.module.scss";

function Header() {
  const context = useDocusaurusContext();
  const { siteConfig = {} } = context;

  return (
    <header id="hero" className={clsx("hero", styles.banner)}>
      <div className="container">
        <img
          src={useBaseUrl(`img/kwatch-logo-full.png`)}
          alt="monitor & detect crashes in your Kubernetes(K8s) cluster instantly"
          className={styles.logo}
        />

        <p className={clsx("hero__subtitle", styles.subtitle)}>
          {siteConfig.tagline}
        </p>

        <div className={styles.buttons}>
          <Link
            className={clsx(
              "button button--primary button--lg",
              styles.getStarted
            )}
            to={useBaseUrl("docs/intro")}
          >
            Get Started
          </Link>

        </div>
        <div className={clsx(styles.buttons, styles.githubStars)}>
          <iframe
            className={styles.githubStarsButton}
            src="https://ghbtns.com/github-btn.html?user=abahmed&amp;repo=kwatch&amp;type=star&amp;count=true&amp;size=large"
            width={160}
            height={30}
            title="GitHub Stars"
          />
        </div>
      </div>
    </header>
  );
}

export default Header;
