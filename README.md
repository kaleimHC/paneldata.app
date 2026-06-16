# paneldata.app

A cross-country panel-data platform: an interactive choropleth world map over millions of country-year development indicators, plus on-demand estimation of a dynamic Panel Vector Autoregression (Panel-VAR, Goes 2016) linking institutions and growth.

Live: https://paneldata.app

Stack: Rails 8.1 + PostgreSQL · Hotwire (Turbo 8 + Stimulus, importmap) + ViewComponent · Tailwind 4 · MapLibre GL · Sidekiq + Redis · R 4.x (plm/pgmm) · Kamal/Docker

Portfolio demo on public, redistributable data. Compute actions (Panel-VAR estimation) are intentionally open to anonymous users.

## What it does

Two things.

**Explore** - pick an indicator and a year, and the MapLibre map repaints the world (choropleth); a year slider animates change over time.

**Analyze** - choose a predictor, a response indicator, a period and a bootstrap depth. The app builds a strictly balanced country-year panel, shells out to R (`plm::pgmm`, one-step first-difference GMM), estimates a Panel-VAR, and renders the impulse-response function (IRF) with bootstrap confidence bands and GMM diagnostics (AR(1) / AR(2) / Sargan).

## Stack

- **Ruby 3.4 / Rails 8.1**, PostgreSQL, Sidekiq + Redis
- **Hotwire** (Turbo 8 view-transitions + Stimulus) on **importmap** (no JS build step) + **ViewComponent**
- **Tailwind CSS 4** (runtime-switchable themes) and **MapLibre GL** for the map
- **R** (`plm` / `pgmm`) for the econometrics; **Kamal** for zero-downtime deploys to a single VPS
- Localized in English, Polish and Spanish (locale-scoped routes)

## Architecture

```
Run config (Stimulus) -> POST /analyses -> AnalysisRun (pending)
  -> PvarJob (Sidekiq) -> PanelBuilder builds a balanced panel CSV
  -> Rscript pvar.R estimates the Panel-VAR (plm::pgmm)
  -> typed rows (gamma / IRF / diagnostics) persisted in PostgreSQL
  -> client polls status, then Turbo-visits /?run=<id> for a server-rendered result
```

## Setup

Prerequisites: Ruby 3.4.4, PostgreSQL, Redis, and (for estimation) R with the `plm` package.

```bash
bin/setup   # install gems and prepare the database
bin/dev     # Rails server + Tailwind watcher
```

Running an estimation additionally needs a Sidekiq worker (`bundle exec sidekiq`) and `Rscript` on PATH.

## License

GPL-3.0 - see `LICENSE`.
