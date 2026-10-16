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
              Full root-cause proof, who changed what, unlimited alert providers and state kept across restarts.
              Free during early access: 3-month licenses, no payment details needed.
              <div style={{marginTop: "1rem"}}>
                <Link className="button button--primary button--lg" to="/signup">
                  Get kwatch Pro free
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
