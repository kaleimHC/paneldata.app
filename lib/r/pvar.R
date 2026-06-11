#!/usr/bin/env Rscript
# =============================================================================
# pvar.R - Panel VAR compute worker.
# The estimation functions below are a VERBATIM port of Patryk's FINAL_STANDALONE.R
# (Goes 2016 replication). ONLY the data-load (WDI/xlsx) is removed: the balanced
# panel arrives as CSV from Rails; this script just computes and emits JSON.
# Column contract: CSV has iso3c, year, response, predictor (raw). The runner maps
# response -> log_gdp, predictor -> log_efw (names are labels; the 2-var estimator is
# variable-name-agnostic, GDP-first Cholesky preserved). Single-thread BLAS
# is enforced by the caller's env (OMP/OPENBLAS/MKL_NUM_THREADS=1); set defensively too.
# =============================================================================
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(plm); library(jsonlite) })

# ===== VERBATIM from FINAL_STANDALONE.R (estimation core - DO NOT MODIFY) =====
# 1a. Matrix power
matrix_power <- function(M, n) {
  if (n == 0) return(diag(nrow(M)))
  if (n == 1) return(M)
  result <- M
  for (i in 2:n) {
    result <- result %*% M
  }
  return(result)
}

# 1b. IRF Goes normalization
compute_irf_goes <- function(gamma, Sigma, h_max = 10) {
  B <- t(chol(Sigma))
  irf <- numeric(h_max + 1)
  shock_vec <- c(0, 1)
  impact <- (diag(2) %*% B %*% shock_vec)[2]
  for (h in 0:h_max) {
    Phi_h <- matrix_power(gamma, h)
    structural_response <- (Phi_h %*% B %*% shock_vec)[1]
    irf[h + 1] <- structural_response / impact
  }
  return(irf)
}

# 1d. PVAR estimation (for bootstrap)
estimate_pvar <- function(pdata) {
  eq1 <- pgmm(log_gdp ~ lag(log_gdp, 1) + lag(log_efw, 1) |
                 lag(log_gdp, 2:99) + lag(log_efw, 2),
               data = pdata, effect = "individual",
               model = "onestep", transformation = "d")

  eq2 <- pgmm(log_efw ~ lag(log_gdp, 1) + lag(log_efw, 1) |
                 lag(log_gdp, 2) + lag(log_efw, 2:99),
               data = pdata, effect = "individual",
               model = "onestep", transformation = "d")

  gamma <- matrix(c(
    coef(eq1)["lag(log_gdp, 1)"], coef(eq1)["lag(log_efw, 1)"],
    coef(eq2)["lag(log_gdp, 1)"], coef(eq2)["lag(log_efw, 1)"]
  ), nrow = 2, byrow = TRUE)

  r1 <- unlist(residuals(eq1))
  r2 <- unlist(residuals(eq2))
  common <- intersect(names(r1), names(r2))

  if (length(common) < 10) {
    stop("Za malo wspolnych residuali: ", length(common))
  }

  Sigma <- cov(cbind(r1[common], r2[common]))
  irf <- compute_irf_goes(gamma, Sigma)

  list(
    gamma = gamma,
    sigma = Sigma,
    B = t(chol(Sigma)),
    irf = irf
  )
}

# 1e. Bootstrap function
bootstrap_pvar_irf <- function(panel, n_boot = 1000, n_exclude = 10,
                                h_max = 10, label = "") {

  countries <- unique(panel$iso3c)
  n_countries <- length(countries)

  cat("\n  Bootstrap konfiguracja:\n")
  cat("    Kraje ogolem:      ", n_countries, "\n")
  cat("    Kraje wykluczane:  ", n_exclude, "\n")
  cat("    Iteracje:          ", n_boot, "\n")
  cat("    Label:             ", label, "\n\n")

  if (n_exclude >= n_countries) {
    stop("n_exclude (", n_exclude, ") >= n_countries (", n_countries, ")")
  }

  irf_matrix <- matrix(NA, nrow = n_boot, ncol = h_max + 1)
  gamma_matrix <- matrix(NA, nrow = n_boot, ncol = 4)
  colnames(gamma_matrix) <- c("g11", "g12", "g21", "g22")
  n_success <- 0
  n_fail <- 0
  errors <- character(0)

  t_start <- Sys.time()
  prog_step <- max(1L, n_boot %/% 40L)   # ~40 progress lines regardless of n_boot (logging cadence only)

  for (b in 1:n_boot) {

    if (b %% prog_step == 0 || b == 1) {
      elapsed <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
      rate <- elapsed / b
      remaining <- rate * (n_boot - b)
      cat(sprintf("    [%s] Iteracja %d/%d | Udane: %d | Rate: %.1f s/iter | ETA: %.0f min\n",
                  label, b, n_boot, n_success, rate, remaining / 60))
    }

    excluded <- sample(countries, n_exclude, replace = FALSE)
    subsample <- panel[!(panel$iso3c %in% excluded), ]

    result <- tryCatch({
      pdata_sub <- pdata.frame(subsample, index = c("iso3c", "year"))
      est <- estimate_pvar(pdata_sub)

      list(
        success = TRUE,
        irf = est$irf,
        gamma = c(est$gamma[1,1], est$gamma[1,2],
                  est$gamma[2,1], est$gamma[2,2])
      )
    }, error = function(e) {
      list(success = FALSE, msg = conditionMessage(e))
    })

    if (result$success) {
      n_success <- n_success + 1
      irf_matrix[b, ] <- result$irf
      gamma_matrix[b, ] <- result$gamma
    } else {
      n_fail <- n_fail + 1
      if (n_fail <= 10) {
        errors <- c(errors, result$msg)
      }
    }
  }

  elapsed_total <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("\n    Bootstrap zakonczony w %.1f min\n", elapsed_total))
  cat(sprintf("    Udane: %d/%d (%.1f%%)\n", n_success, n_boot,
              100 * n_success / n_boot))
  if (n_fail > 0) {
    cat(sprintf("    Nieudane: %d (pierwsze bledy: %s)\n",
                n_fail, paste(head(errors, 3), collapse = "; ")))
  }

  valid <- !is.na(irf_matrix[, 1])
  irf_valid <- irf_matrix[valid, , drop = FALSE]
  gamma_valid <- gamma_matrix[valid, , drop = FALSE]

  if (nrow(irf_valid) < 10) {
    warning("Zbyt malo udanych iteracji: ", nrow(irf_valid))
    return(list(
      irf_matrix = irf_valid,
      gamma_matrix = gamma_valid,
      irf_mean = rep(NA, h_max + 1),
      irf_sd = rep(NA, h_max + 1),
      n_success = n_success,
      n_fail = n_fail,
      elapsed_min = elapsed_total
    ))
  }

  list(
    irf_matrix = irf_valid,
    gamma_matrix = gamma_valid,
    irf_mean = colMeans(irf_valid),
    irf_sd = apply(irf_valid, 2, sd),
    n_success = n_success,
    n_fail = n_fail,
    elapsed_min = elapsed_total
  )
}

# 1f. Confidence intervals
compute_ci <- function(boot, canonical_irf) {
  list(
    goes_lower = canonical_irf - 1.645 * boot$irf_sd,
    goes_upper = canonical_irf + 1.645 * boot$irf_sd,
    pct_lower = apply(boot$irf_matrix, 2, quantile, probs = 0.05),
    pct_upper = apply(boot$irf_matrix, 2, quantile, probs = 0.95)
  )
}
estimate_full_diagnostics <- function(panel) {

  pdata <- pdata.frame(panel, index = c("iso3c", "year"))

  # Equation 1: log_gdp (identical pgmm call)
  eq1 <- pgmm(log_gdp ~ lag(log_gdp, 1) + lag(log_efw, 1) |
                lag(log_gdp, 2:99) + lag(log_efw, 2),
              data = pdata, effect = "individual",
              model = "onestep", transformation = "d")

  # Equation 2: log_efw (identical pgmm call)
  eq2 <- pgmm(log_efw ~ lag(log_gdp, 1) + lag(log_efw, 1) |
                lag(log_gdp, 2) + lag(log_efw, 2:99),
              data = pdata, effect = "individual",
              model = "onestep", transformation = "d")

  s1 <- summary(eq1)
  s2 <- summary(eq2)

  # Gamma matrix
  gamma <- matrix(c(
    coef(eq1)["lag(log_gdp, 1)"], coef(eq1)["lag(log_efw, 1)"],
    coef(eq2)["lag(log_gdp, 1)"], coef(eq2)["lag(log_efw, 1)"]
  ), 2, 2, byrow = TRUE)
  rownames(gamma) <- c("log_gdp", "log_efw")
  colnames(gamma) <- c("L.log_gdp", "L.log_efw")

  # P-value matrix
  pval <- matrix(c(
    s1$coefficients["lag(log_gdp, 1)", "Pr(>|z|)"],
    s1$coefficients["lag(log_efw, 1)", "Pr(>|z|)"],
    s2$coefficients["lag(log_gdp, 1)", "Pr(>|z|)"],
    s2$coefficients["lag(log_efw, 1)", "Pr(>|z|)"]
  ), 2, 2, byrow = TRUE)
  rownames(pval) <- c("log_gdp", "log_efw")
  colnames(pval) <- c("L.log_gdp", "L.log_efw")

  # Diagnostics: AR(1), AR(2), Sargan
  extract_diag <- function(eq, s) {
    ar1 <- tryCatch({ t <- mtest(eq, order = 1); list(stat = t$statistic, pval = t$p.value) },
                     error = function(e) list(stat = NA, pval = NA))
    ar2 <- tryCatch({ t <- mtest(eq, order = 2); list(stat = t$statistic, pval = t$p.value) },
                     error = function(e) list(stat = NA, pval = NA))
    sarg <- tryCatch({ t <- sargan(eq); list(stat = t$statistic, df = t$parameter, pval = t$p.value) },
                      error = function(e) list(stat = NA, df = NA, pval = NA))
    # Wald test from summary
    wald_stat <- NA; wald_df <- NA; wald_pval <- NA
    if (!is.null(s$wald.test)) {
      wald_stat <- s$wald.test["chisq"]
      wald_df   <- s$wald.test["df"]
      wald_pval <- s$wald.test["p-value"]
    }
    list(ar1_stat = ar1$stat, ar1_pval = ar1$pval,
         ar2_stat = ar2$stat, ar2_pval = ar2$pval,
         sargan_stat = sarg$stat, sargan_df = sarg$df, sargan_pval = sarg$pval,
         wald_stat = wald_stat, wald_df = wald_df, wald_pval = wald_pval)
  }
  diag_eq1 <- extract_diag(eq1, s1)
  diag_eq2 <- extract_diag(eq2, s2)

  # Sigma and Cholesky - match residuals by name (same logic as estimate_pvar)
  r1 <- unlist(residuals(eq1))
  r2 <- unlist(residuals(eq2))
  common <- intersect(names(r1), names(r2))
  if (length(common) < 10) {
    stop("Za malo wspolnych residuali w diagnostyce: ", length(common))
  }
  Sigma <- cov(cbind(r1[common], r2[common]))
  rownames(Sigma) <- c("e_gdp", "e_efw")
  colnames(Sigma) <- c("e_gdp", "e_efw")
  B_chol <- t(chol(Sigma))

  # IRF (non-normalized, Phi_h[1,2]) - used for verification / point estimates
  # NOTE: This is Phi^h[1,2] WITHOUT Goes normalization.
  # For bootstrap CI and plots, compute_irf_goes is used instead (with Cholesky).
  # Both give very similar values when B[1,2] ~ 0 (which holds here).
  irf_1pct <- numeric(11)
  for (h in 0:10) {
    phi_h <- matrix_power(gamma, h)
    irf_1pct[h + 1] <- phi_h[1, 2]
  }

  # Peak
  gamma_12 <- gamma[1, 2]
  if (gamma_12 >= 0) {
    peak_idx <- which.max(irf_1pct)
  } else {
    peak_idx <- which.min(irf_1pct)
  }

  list(
    gamma = gamma,
    pval = pval,
    gamma_12 = gamma_12,
    p_gamma_12 = pval[1, 2],
    diag_eq1 = diag_eq1,
    diag_eq2 = diag_eq2,
    Sigma = Sigma,
    B = B_chol,
    irf_1pct = irf_1pct,
    peak_h = peak_idx - 1,
    peak_irf = irf_1pct[peak_idx],
    N = length(unique(panel$iso3c)),
    T_years = length(unique(panel$year))
  )
}

# ===== RUNNER (data plumbing + JSON I/O - NOT estimation) =====
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) stop("usage: pvar.R <config.json>")
cfg <- fromJSON(args[[1]])
set.seed(if (!is.null(cfg$seed)) cfg$seed else 42L)

write_json_out <- function(obj) {
  con <- file(cfg$output_path, "w")
  writeLines(toJSON(obj, auto_unbox = TRUE, null = "null", na = "null", digits = 12), con)
  close(con)
}

res <- tryCatch({
  raw <- read.csv(cfg$csv_path, stringsAsFactors = FALSE)
  raw <- raw[!is.na(raw$response) & !is.na(raw$predictor), ]
  raw$log_gdp <- log(raw$response)   # response  -> log_gdp (Cholesky first)
  raw$log_efw <- log(raw$predictor)  # predictor -> log_efw (Cholesky second)
  if (any(!is.finite(raw$log_gdp)) || any(!is.finite(raw$log_efw)))
    stop("log-transform undefined (non-positive values) for this indicator pair")

  T_years <- length(unique(raw$year))
  cnt <- table(raw$iso3c); keep <- names(cnt[cnt == T_years])
  panel <- raw[raw$iso3c %in% keep, ]
  panel <- panel[order(panel$iso3c, panel$year), ]
  if (length(unique(panel$iso3c)) < 5)
    stop(sprintf("balanced panel too small: %d countries", length(unique(panel$iso3c))))

  diag <- estimate_full_diagnostics(panel)
  pdata <- pdata.frame(panel, index = c("iso3c", "year"))
  est <- estimate_pvar(pdata)
  irf <- est$irf                                  # canonical (compute_irf_goes), matches bootstrap CI
  peak_idx <- which.max(abs(irf))

  nb <- if (!is.null(cfg$n_bootstrap)) as.integer(cfg$n_bootstrap) else 0L
  cl <- rep(NA_real_, length(irf)); cu <- rep(NA_real_, length(irf)); boot_blob <- NULL
  if (nb > 0) {
    boot <- bootstrap_pvar_irf(panel, n_boot = nb,
                               n_exclude = if (!is.null(cfg$n_exclude)) as.integer(cfg$n_exclude) else 10L,
                               label = "run")
    ci <- compute_ci(boot, irf)
    cl <- ci$goes_lower; cu <- ci$goes_upper
    boot_blob <- list(irf_matrix = boot$irf_matrix, gamma_matrix = boot$gamma_matrix,
                      n_success = boot$n_success, n_fail = boot$n_fail)
  }

  rn <- c("log_gdp", "log_efw"); cn <- c("L.log_gdp", "L.log_efw")
  gamma_rows <- list()
  for (i in 1:2) for (j in 1:2)
    gamma_rows[[length(gamma_rows) + 1]] <- list(
      equation = rn[i], regressor = cn[j],
      coefficient = diag$gamma[i, j], p_value = diag$pval[i, j])

  # Coerce to a plain numeric scalar. plm 2.6.2's mtest returns $statistic/$p.value as 1x1 MATRICES
  # (named "normal"), which toJSON serializes as nested arrays -> Rails stores 0.0. as.numeric[1] strips
  # the dim so AR(1)/AR(2) survive on any plm version (no-op for the scalars plm 2.6.7 returns).
  n1 <- function(x) { v <- suppressWarnings(as.numeric(x)); if (length(v) == 0L) NA_real_ else v[1] }

  # AR(1)/AR(2)/Sargan only - exactly the diagnostics the thesis reports (Tab. 6). Wald is dropped: pgmm's
  # summary does not populate it (always empty), and it is not part of the reported set. FEVD is a VAR output,
  # not a diagnostic, and the thesis deliberately does not report it - so it stays out of this section.
  mk_diag <- function(eq, d) list(
    list(equation = eq, test_name = "AR1",    statistic = n1(d$ar1_stat),    p_value = n1(d$ar1_pval),    df = NA),
    list(equation = eq, test_name = "AR2",    statistic = n1(d$ar2_stat),    p_value = n1(d$ar2_pval),    df = NA),
    list(equation = eq, test_name = "Sargan", statistic = n1(d$sargan_stat), p_value = n1(d$sargan_pval), df = n1(d$sargan_df)))

  list(
    status = "completed",
    gamma_12 = n1(diag$gamma_12), p_gamma_12 = n1(diag$p_gamma_12),
    gamma_21 = n1(diag$gamma[2, 1]), p_gamma_21 = n1(diag$pval[2, 1]),  # bidirectionality (Goes): GDP -> EFW
    peak_irf = irf[peak_idx], peak_horizon = peak_idx - 1L,
    n_countries = diag$N, n_years = diag$T_years,
    gamma = gamma_rows,
    irf = lapply(seq_along(irf), function(k)
      list(horizon = k - 1L, irf = irf[k], ci_lower = cl[k], ci_upper = cu[k])),
    diagnostics = c(mk_diag("log_gdp", diag$diag_eq1), mk_diag("log_efw", diag$diag_eq2)),
    bootstrap = boot_blob,
    r_version = as.character(getRversion()),
    package_versions = list(plm = as.character(packageVersion("plm")))
  )
}, error = function(e) list(status = "failed", error = conditionMessage(e)))

write_json_out(res)
