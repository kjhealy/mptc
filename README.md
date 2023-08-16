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
  subgraph legend
    direction LR
    x7420bd9270f8d27d([&quot;&quot;Up to date&quot;&quot;]):::uptodate --- x0a52b03877696646([&quot;&quot;Outdated&quot;&quot;]):::outdated
    x0a52b03877696646([&quot;&quot;Outdated&quot;&quot;]):::outdated --- xbf4603d6c2c2ad6b([&quot;&quot;Stem&quot;&quot;]):::none
    xbf4603d6c2c2ad6b([&quot;&quot;Stem&quot;&quot;]):::none --- xf0bce276fe2b9d3e&gt;&quot;&quot;Function&quot;&quot;]:::none
    xf0bce276fe2b9d3e&gt;&quot;&quot;Function&quot;&quot;]:::none --- x5bffbffeae195fc9{{&quot;&quot;Object&quot;&quot;}}:::none
  end
  subgraph Graph
    direction LR
    xcf51c9ec8bfa2e15&gt;&quot;format_days&quot;]:::uptodate --&gt; xea968c7c6660f0c6&gt;&quot;build_schedule_for_page&quot;]:::uptodate
    x9c20b8c56debbe9a([&quot;deploy_script&quot;]):::uptodate --&gt; x78f3e0b711425f1c([&quot;deploy_site&quot;]):::outdated
    x7aa56383a054e8ba([&quot;site&quot;]):::outdated --&gt; x78f3e0b711425f1c([&quot;deploy_site&quot;]):::outdated
    x4d31f5a49d5ae49f([&quot;schedule_ical_file&quot;]):::uptodate --&gt; x7aa56383a054e8ba([&quot;site&quot;]):::outdated
    x063edd335cc1b36f([&quot;schedule_page_data&quot;]):::uptodate --&gt; x7aa56383a054e8ba([&quot;site&quot;]):::outdated
    x17f2ff3caa2e3a1e&gt;&quot;here_rel&quot;]:::uptodate --&gt; x9c20b8c56debbe9a([&quot;deploy_script&quot;]):::uptodate
    xea968c7c6660f0c6&gt;&quot;build_schedule_for_page&quot;]:::uptodate --&gt; x063edd335cc1b36f([&quot;schedule_page_data&quot;]):::uptodate
    xdf832f8e1f99baf2([&quot;schedule_file&quot;]):::uptodate --&gt; x063edd335cc1b36f([&quot;schedule_page_data&quot;]):::uptodate
    x17f2ff3caa2e3a1e&gt;&quot;here_rel&quot;]:::uptodate --&gt; xdf832f8e1f99baf2([&quot;schedule_file&quot;]):::uptodate
    x24dc016daf163777{{&quot;base_url&quot;}}:::uptodate --&gt; x35552a73efe9c59f([&quot;schedule_ical_data&quot;]):::uptodate
    xf9eb722d9d2f4742&gt;&quot;build_ical&quot;]:::uptodate --&gt; x35552a73efe9c59f([&quot;schedule_ical_data&quot;]):::uptodate
    x60f76b6f1d5230d7{{&quot;class_number&quot;}}:::uptodate --&gt; x35552a73efe9c59f([&quot;schedule_ical_data&quot;]):::uptodate
    x5135e16fe6c96d4f{{&quot;page_suffix&quot;}}:::uptodate --&gt; x35552a73efe9c59f([&quot;schedule_ical_data&quot;]):::uptodate
    xdf832f8e1f99baf2([&quot;schedule_file&quot;]):::uptodate --&gt; x35552a73efe9c59f([&quot;schedule_ical_data&quot;]):::uptodate
    x17f2ff3caa2e3a1e&gt;&quot;here_rel&quot;]:::uptodate --&gt; x4d31f5a49d5ae49f([&quot;schedule_ical_file&quot;]):::uptodate
    x39564e0a27dee01a&gt;&quot;save_ical&quot;]:::uptodate --&gt; x4d31f5a49d5ae49f([&quot;schedule_ical_file&quot;]):::uptodate
    x35552a73efe9c59f([&quot;schedule_ical_data&quot;]):::uptodate --&gt; x4d31f5a49d5ae49f([&quot;schedule_ical_file&quot;]):::uptodate
    x6e52cb0f1668cc22([&quot;readme&quot;]):::outdated --&gt; x6e52cb0f1668cc22([&quot;readme&quot;]):::outdated
    xf38d3f5e6365ad72([&quot;workflow_graph&quot;]):::uptodate --&gt; xf38d3f5e6365ad72([&quot;workflow_graph&quot;]):::uptodate
    x87c804cb70e60e70&gt;&quot;zippy&quot;]:::uptodate --&gt; x87c804cb70e60e70&gt;&quot;zippy&quot;]:::uptodate
    x262d0ad82d5b0b8c&gt;&quot;save_csv&quot;]:::uptodate --&gt; x262d0ad82d5b0b8c&gt;&quot;save_csv&quot;]:::uptodate
    x442d930fac0132ed&gt;&quot;copy_file&quot;]:::uptodate --&gt; x442d930fac0132ed&gt;&quot;copy_file&quot;]:::uptodate
  end
  classDef uptodate stroke:#000000,color:#ffffff,fill:#354823;
  classDef outdated stroke:#000000,color:#000000,fill:#78B7C5;
  classDef none stroke:#000000,color:#000000,fill:#94a4ac;
  linkStyle 0 stroke-width:0px;
  linkStyle 1 stroke-width:0px;
  linkStyle 2 stroke-width:0px;
  linkStyle 3 stroke-width:0px;
  linkStyle 21 stroke-width:0px;
  linkStyle 22 stroke-width:0px;
  linkStyle 23 stroke-width:0px;
  linkStyle 24 stroke-width:0px;
  linkStyle 25 stroke-width:0px;
```
