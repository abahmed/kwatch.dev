import React, { useEffect, useState, useCallback } from "react";
import { useColorMode } from "@docusaurus/theme-common";
import { Highlight, themes as prismThemes } from "prism-react-renderer";
import type { Language } from "prism-react-renderer";

import styles from "./styles.module.css";

interface CodeSnippetProps {
  code: string;
  language?: Language;
}

function CodeSnippet({ code, language = "bash" }: CodeSnippetProps) {
  const [mounted, setMounted] = useState(false);
  const [copied, setCopied] = useState(false);
  const { colorMode } = useColorMode();

  useEffect(() => {
    setMounted(true);
  }, []);

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
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
        key={mounted ? "mounted" : "server"}
        code={code}
        language={language}
        theme={colorMode === "dark" ? prismThemes.dracula : prismThemes.github}
      >
        {({ className, style, tokens, getLineProps, getTokenProps }) => (
          <pre className={`${className} ${styles.code}`} style={style}>
            {tokens.map((line, i) => (
              <div key={i} {...getLineProps({ line })}>
                {line.map((token, key) => (
                  <span key={key} {...getTokenProps({ token })} />
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
