## How to Run

1. Open the `dolphins.txt` file in NetLogo.
2. Install the dbscan plugin when prompted.

The model has been tested with NetLogo 6.4.0.

# Predator-Prey Dynamics Simulation

This repository contains code and resources for an agent-based model (ABM) simulation of predator-prey dynamics between dolphins (predators) and fish (prey). The models were developed to explore and analyze emergent behaviors and interactions.

## Overview

Three models of increasing complexity are implemented:

1. **Baseline Model**: Simple chasing and fleeing behavior between dolphins and fish.
2. **Schooling Model**: Adds fish schooling behavior, inspired by Craig Reynolds' Boids model.
3. **Hunting Strategy Model**: Introduces dolphin communication for coordinated hunting.

## Features

- Fish and dolphins interact in a 2D toroidal space.
- Adjustable parameters for speed, vision range, and turning angles.
- Visualizations of emergent behaviors such as divergence, schooling, and coordinated hunting.
- Reproducible experiments included in the model

## How to use it

The model includes some demo presets for fish behavior; choose one, then tweak dolphin numbers.
Have fun experimenting with other parameters

## Implementation notes

The model uses the dbscan netlogo extension, developed by Christopher Frantz. It is available at https://github.com/chrfrantz/NetLogo-Extension-DBSCAN
The extension implements [DBSCAN](https://en.wikipedia.org/wiki/DBSCAN) for densitity based clustering.
(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## Credits and Reference

This model adapts the flocking behavior from the following model:

- Wilensky, U. (1998). NetLogo Flocking model. http://ccl.northwestern.edu/netlogo/models/Flocking. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

This model was created for the course Complex Systems & Network Science at the University of Bologna.

## Contact

For questions or contributions, contact:
Andrea Corradetti  
[andrea.corradetti2@studio.unibo.it](mailto:andrea.corradetti2@studio.unibo.it)