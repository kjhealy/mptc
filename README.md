# README File

<!-- README.md is generated from README.qmd. Please edit that file -->

# SOCIOL 880-1: Modern Plain Text Computing

- Taught by Kieran Healy, Duke University
- Fall 2023

This is the source code for the course website at <https://mptc.io>

The site is a [Quarto](https://quarto.org) project. It uses
[{{renv}}](https://rstudio.github.io/renv/) to manage dependencies and
[{{targets}}](https://docs.ropensci.org/targets/) to manage the site
building.

## Everything is a DAG now

Here is the dependency graph for the site build.

``` mermaid
graph LR
  subgraph Graph
    direction LR
    x9c20b8c56debbe9a(["deploy_script"]):::built --> x78f3e0b711425f1c(["deploy_site"]):::queued
    x7aa56383a054e8ba(["site"]):::built --> x78f3e0b711425f1c(["deploy_site"]):::queued
    xf38d3f5e6365ad72(["workflow_graph"]):::started --> x6e52cb0f1668cc22(["readme"]):::queued
    xdf832f8e1f99baf2(["schedule_file"]):::queued --> x063edd335cc1b36f(["schedule_page_data"]):::queued
    xdf832f8e1f99baf2(["schedule_file"]):::queued --> x35552a73efe9c59f(["schedule_ical_data"]):::queued
    x35552a73efe9c59f(["schedule_ical_data"]):::queued --> x4d31f5a49d5ae49f(["schedule_ical_file"]):::queued
  end
```
