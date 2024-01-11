import React from "react";
import styles from "./styles.module.css";

function Waitlist() {
  return (
    <section id="waitlist" className={styles.installation}>
      <div className="container">
        <div className="row">
          <div className="col col--10 col--offset-1">
            <div className={styles.headline}>
              <span className={styles.category}>Join Waitlist</span>
              <br/>
              We're working on SAAS version of kwatch that provides User interface, optimized notifications, more details about crashes, and more.
              you can join <a href="https://join.kwatch.dev">the waitlist</a> if you're interested.
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default Waitlist;
