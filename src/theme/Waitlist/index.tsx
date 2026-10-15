import React from "react";
import Link from "@docusaurus/Link";
import styles from "./styles.module.css";

function Waitlist() {
  return (
    <section id="waitlist" className={styles.installation}>
      <div className="container">
        <div className="row">
          <div className="col col--10 col--offset-1">
            <div className={styles.headline}>
              <span className={styles.category}>kwatch Pro</span>
              <br/>
              Full root-cause proof, who changed what, unlimited alert providers and 90 days of incident history.
              Try everything free for 90 days, no credit card needed.
              <div style={{marginTop: "1rem"}}>
                <Link className="button button--primary button--lg" to="/signup">
                  Start free Pro trial
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default Waitlist;
