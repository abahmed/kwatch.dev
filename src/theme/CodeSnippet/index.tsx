import React, { useEffect, useState } from "react";
import { Highlight, themes } from "prism-react-renderer";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import {themes as prismThemes} from 'prism-react-renderer';

import styles from "./styles.module.css";

function CodeSnippet(props) {
  const [mounted, setMounted] = useState(null);

  useEffect(() => {
    setMounted(true);
  }, []);

  const { language = "bash", code } = props;

  return (
    <Highlight
      key={mounted}
      code={code}
      language={language}
      theme={prismThemes.github}
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
