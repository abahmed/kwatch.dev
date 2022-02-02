import React, { useEffect, useState } from "react";
import Highlight, { defaultProps } from "prism-react-renderer";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";

import styles from "./styles.module.scss";

function CodeSnippet(props) {
  const {
    siteConfig: {
      themeConfig: { prism = {} },
    },
  } = useDocusaurusContext();

  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const { isDarkTheme } = false;
  const lightModeTheme = prism.theme;
  const darkModeTheme = prism.darkTheme || lightModeTheme;
  const prismTheme = isDarkTheme ? darkModeTheme : lightModeTheme;

  const { language = "bash", code } = props;

  return (
    <Highlight
      {...defaultProps}
      code={code}
      language={language}
      key={mounted}
      theme={prismTheme}
      className={styles.snippet}
    >
      {({ className, style, tokens, getLineProps, getTokenProps }) => (
        <pre className={`${className} ${styles.code}`} style={style}>
          {tokens.map((line, i) => (
            <div {...getLineProps({ line, key: i })}>
              {line.map((token, key) => (
                <span {...getTokenProps({ token, key })} />
              ))}
            </div>
          ))}
        </pre>
      )}
    </Highlight>
  );
}

export default CodeSnippet;
