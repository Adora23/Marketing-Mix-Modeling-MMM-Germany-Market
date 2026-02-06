# **Marketing Mix Modeling (MMM) — Germany Market**

## **Project Overview**

This project builds a Marketing Mix Model (MMM) to quantify how marketing activities impact weekly revenue in the German market. The primary objective is to provide a data-driven framework for understanding media effectiveness and informing budget allocation decisions, while explicitly addressing the statistical and business limitations of MMM in real-world settings.

Rather than forcing strong uplift results, this project emphasizes model diagnostics, interpretability, and decision-making discipline, reflecting how MMM should be applied in practice.

---

## **Business Objective**

Quantify the incremental contribution of marketing channels to revenue and assess whether budget reallocation would lead to meaningful revenue uplift.

Key questions:

* How much revenue can be attributed to paid media?

* Are media effects distinguishable from seasonality and trend?

* Does reallocating the budget improve total revenue?

---

## **Data Description**

**Granularity:** Weekly  
 **Market:** Germany

### **Core variables:**

* `weekly_revenue` – total weekly revenue (target)

* `google_spend`, `meta_spend` – paid media investment

* `email_volume` – owned channel activity (explored but excluded from final model)

* `promo_flag` – promotional weeks

* `is_holiday_season` – seasonal indicator

* `time_index` – linear trend proxy

---

## **Methodology**

The project follows a classical MMM workflow, with increasing model sophistication and diagnostics at each step.

### **1️. Data Preparation**

* Weekly aggregation

* Feature validation and consistency checks

* Time index creation for long-term trend

---

### **2️. Media Transformations**

To reflect real advertising dynamics:

* **Adstock**  
   Captures carryover effects of media exposure.

* **Log Transformations**  
   Stabilizes variance and reduces scale dominance.

* **Hill Saturation Curves**  
   Models diminishing returns at higher spend levels.

Both log and Hill specifications were tested and compared.

---

### **3️. Baseline Regression (OLS)**

Initial OLS models included:

* Media variables

* Promotional and seasonal controls

* Time trend

This established a baseline understanding of fit and coefficient stability.

---

### **4️. Model Diagnostics**

To ensure statistical validity:

* **Correlation Matrix**

  * Strong correlations between media spend and seasonality were observed.

* **Variance Inflation Factor (VIF)**

  * Elevated VIFs for media and holiday variables indicated multicollinearity.

* **Residual diagnostics**

  * Normality violations and weak explanatory power were identified.

These diagnostics informed subsequent modeling decisions.

---

### **5️. Constrained MMM (Non-Negative Media Coefficients)**

To improve business realism:

* Media coefficients were constrained to be non-negative

* This avoids implausible negative media impact

* Ensures interpretable contribution analysis

---

### **6️. Contribution Decomposition**

Using constrained coefficients:

* Channel-level revenue contributions were computed

* Contribution shares were compared across channels

This represents the core output of an MMM.

---

### **7️.  Budget Reallocation Simulation**

Scenario analysis tested whether reallocating spend:

* Increased predicted revenue

* Generated positive incremental uplift

The simulation showed no material uplift, which became a key insight rather than a failure.

---

##  **Key Findings**

### **🔹 Media spend is highly correlated with seasonality**

* Paid media activity closely tracks holiday periods

* This limits causal identifiability of media effects

### **🔹 Incremental media impact is weak and unstable**

* Media coefficients vary across specifications

* Meta converges toward zero under constraints

### **🔹 No uplift from budget reallocation**

* Reallocation scenarios do not improve predicted revenue

* Suggests demand and seasonality dominate performance

---

##  **Business Interpretation**

These results indicate that:

* MMM should not be used for aggressive budget optimization in this context

* Media effectiveness cannot be reliably separated from seasonal demand

* Budget decisions should be supported by incrementality experiments (e.g. geo-tests, holdouts)

* MMM remains useful as a directional and monitoring tool, not a sole decision engine

This outcome reflects a realistic MMM application, not a synthetic or over-fit model.

---

##  **Limitations**

* Small sample size (53 weeks)

* High multicollinearity between media and seasonal drivers

* Lack of experimental variation in media spend

* Limited owned-channel signal (email)

---

##  **Future Improvements**

If extended further, this project could include:

* Explicit modeling of owned channels (email, CRM)

* Bayesian MMM for uncertainty quantification

* Geo-level or experiment-informed priors

* Integration with incrementality test results

* Finer temporal granularity (daily data)

---

##  **Key Takeaway**

A strong MMM does not always produce strong uplift —  
but it always produces clarity about what decisions should *not* be made.

This project demonstrates how to build, diagnose, and responsibly interpret an MMM in a real-world business setting.

