# Buffers or corridors for the great crested newts

This repository contains the NetLogo model code and also the code for analysing the model. The model can be found [here](model/crested_newt.nlogo). The simulation experiments and the sensitivity analysis are found in the folder [model analysis](model%20analysis).

![model overview](additional%20material%20for%20report/newts_overview.svg)



## Installation 

In order to run the model NetLogo and a Python installation is needed. Additionally the Python packages scipy, numpy, scikit-image and shapely are required. Additionally, the NetLogo extensions shell and gis are required. Please keep the folder structure within /model otherwise the Python script for creating the landscape and the pcolor.asc cannot be found.

Under Ubuntu systems Python and the packages can be installed with:

```bash
sudo apt install python3
pip3 install scipy numpy shapely scikit-image
```



If Python is not installed in the global path, the NetLogo code have to be adjusted in order to find the Python installation.







MIT License

Copyright (c) 2021 Felix Nößler, Susanne Kohrs, Maximillian Hedt