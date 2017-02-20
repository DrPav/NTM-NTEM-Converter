Readme
================

Overview
--------

This internal DfT tool takes outputs of the National Trip Ends Model (NTEM) and converts them ready to be used for the National Transport Model.

The code is written in R and the user interacts with the tool via a simple [R Shiny](https://shiny.rstudio.com/) app.

Usage
-----

Start the app by launching an R console and running

``` r
shiny::runApp(appDir = 'your/path/to/NTM-ULC-APP')
```

changing the path to be where you placed the folder on your system. **The app only works on 32-bit R** since the NTEM databases are stored in 32-bit ms office format.

Select the options and click "go". The processing will take about 5-10 minutes.

### Required R packages

The following R packages need to be installed

``` r
install.packages("tidyverse")
install.packages("RODBC")
install.packages("gdata")
install.packages("shiny")
```

### App options

The app will ask you for

-   Path to a folder containing the cTripEnds database files from NTEM
-   Path to a folder to output the ULC files for NTM
-   An option to select either base or policy NTM run type.

### Inputs

The cTripEnds folder must contain 9 cTripEnds databases, one for each NTEM year 2011 to 2051 in 5 year increments. The year must be included within the name of the file - e.g. ctripends7-2016.accdb

### Outputs

The program will output ULC.dat files for each NTM year - 2011, 2015, 2020, 2025, 2030, 2035, 2040, 2045, 2050 It will additionally output intermediate csv tables calculated as part of the part conversion process.

### NTM run type

A ULC file type of *base* or *policy* must be selected. See NTM documentation for the difference. It is related to constraints on trips.

Structure
---------

The conversion process is applied by replicating the conversion spreadsheets supplied as part of NTMv2R.

-   NTEM\_NTS\_Link\_v1.0.xlsm
-   P1\_ULC\_NTMv2R\_v1.5.xlsm

Two R functions are contained within the folder *R functions*, one for each spreadsheet.

### Front end

A [R Shiny app](https://shiny.rstudio.com/) consists of server.R for the calculations and ui.R for the user interface. On clicking "go" the app calls the two R functions required to convert the files. The arguments to the functions (directories) are provided by the user inputs.

### Lookup tables

The spreadsheets convert trip productions and attractions from NTEM zoning system, modes and purposes to that of NTM. Lookup tables were extracted from the spreadsheets to assist with these conversions. The folder *lookups* contains lookup tables as csv files for:

-   person and household type
-   loflow classification
-   trip purpose
-   geographical zone
-   db constraints for ULC base files

### Function 01 - replicate NTEM\_NTS\_Link

1.  Use the *RODBC* package to extract trip ends data from the ms access files
2.  Convert the data into the required format, including seperating home based and non-home based trips and the different NTM segmentations
3.  Repeat for each NTEM year
4.  Save a intermediate table for each year and productions/attractions as a csv in the output folder
5.  Use linear interpolation to get productions and attractions for each NTM year
6.  Save a intermediate table for each interpolated NTM year and productions/attractions as a csv in the output folder

### Function 02 - replicate P1\_ULC\_NTv2R

1.  Take the interpolated data for each NTM year from function 01
2.  Calculate the constraints if the user has selected *base*
3.  Save the data as a ulc.dat file in the particular format required for NTM. The *gdata* R package is used to save tables in a fixed width format.
