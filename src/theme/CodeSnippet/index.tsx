import React, { useEffect, useState, useCallback } from "react";
import { Highlight } from "prism-react-renderer";
import {themes as prismThemes} from 'prism-react-renderer';

import styles from "./styles.module.css";

function CodeSnippet(props) {
  const [mounted, setMounted] = useState(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const { language = "bash", code } = props;

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }, [code]);

  return (
    <div className={styles.wrapper}>
      <button
        className={`${styles.copyBtn} ${copied ? styles.copied : ''}`}
        onClick={handleCopy}
        aria-label={copied ? 'Copied!' : 'Copy code'}
      >
        {copied ? '✅ Copied!' : '📋 Copy'}
      </button>
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
    </div>
  );
}

export default CodeSnippet;
