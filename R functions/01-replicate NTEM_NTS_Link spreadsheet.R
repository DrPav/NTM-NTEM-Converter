

# Run and save transformations to CSV (32bit memory limit) ------------------------------------------------
extract_and_transform <- function(ctripends_directory, output_dir){
  require(RODBC)
  # Load the lookups --------------------------------------------------------
  
  lookup_traveller <- read_csv("lookups/ntm hh and person.csv")
  lookup_loflow <- read_csv("lookups/ntm loflow.csv")
  lookup_purpose <- read_csv("lookups/ntm purpose.csv")
  lookup_zone <- read_csv("lookups/ntm zones.csv")
  
  # Data transformation function -----------------------------------------------------------
  generate_trip_ends <- function(zonePurp, tPhis){
    #Function requires the lookup tables loaded into memory
    # Munge zonePurp ----------------------------------------------------------
    
    zonePurp_clean <- zonePurp %>%
      # Dont need weight cols
      select(-W, -WM1, -WM2, -WM3, -WM4, -WM5, -WM6) %>% 
      # Make long
      gather(key, value, PM1D1:PM6C4) %>%
      # remove "C" cols
      filter(!str_detect(key, "C")) %>%
      #Pull out first letter in key (P or A or O or D)
      mutate(poad = str_sub(key, 1, 1)) %>%
      # reduce to Productions and attractions
      filter(poad %in% c("P", "A")) %>%
      #Join on NTM lookup codes
      left_join(lookup_zone, by = c("I" = "NTEM7_Zone_ID")) %>%
      left_join(lookup_purpose, by = c("P" = "NTEM7 Trip Purpose")) %>%
      # Reduce to key columns
      select(NTM_Zone = NTMv2R_Zone_Number,
             NTM_Purpose = `NTMv2R Trip Purpose`,
             poad,
             value) %>%
      #aggregate by productions/attractions and NTM zone and purpose. Divide by 7 for average day
      group_by(NTM_Zone, NTM_Purpose, poad) %>%
      summarise(value = sum(value) / 7) %>%
      ungroup
    
    
    # Munge TPhis -------------------------------------------------------------
    #Table of Home Based productions by traveller type
    tPhis_clean <- tPhis %>%
      #Make long
      gather(NTEM_Person, productions, S001:S088) %>%
      mutate(NTEM_Person = str_sub(NTEM_Person, 2, 4) %>% as.integer) %>%
      # Join NTM codes
      left_join(lookup_zone, by = c("I" = "NTEM7_Zone_ID")) %>%
      left_join(lookup_purpose, by = c("H" = "NTEM7 Trip Purpose")) %>%
      left_join(lookup_traveller, by = c("NTEM_Person" = "NTEM traveller code")) %>%
      select(NTM_Zone = NTMv2R_Zone_Number,
             NTM_Purpose = `NTMv2R Trip Purpose`,
             NTM_HH = `NTM household type`,
             NTM_Person = `NTM person type`,
             productions) %>%
      #Aggregate
      group_by(NTM_Zone, NTM_Purpose, NTM_HH, NTM_Person) %>%
      summarise(Productions = sum(productions) / 7) %>%
      ungroup %>%
      #Don't include Purpose 6 as that will go with NHB later
      filter(NTM_Purpose != 6)
    
    
    # Attractions Output ------------------------------------------------------
    
    attractions_output <- zonePurp_clean %>%
      filter(poad == "A") %>%
      select(NTM_Purpose, NTM_Zone, Attractions = value) %>%
      arrange(NTM_Purpose, NTM_Zone)
    
    
    
    # Productions Output ------------------------------------------------------
    #Non-Home Based Trips
    nhb_productions <- zonePurp_clean %>%
      filter(poad == "P", NTM_Purpose %in% c(6,7,8)) %>%
      mutate(NTM_HH = 0, NTM_Person = 0) %>%
      select(NTM_Zone, NTM_Purpose, NTM_HH, NTM_Person, Productions = value)
    # Combine NHB + HB Products
    productions <- rbind(nhb_productions, tPhis_clean)
    
    #Join up to the loflow table and then aggregate to lo flows
    productions_output <- left_join(lookup_loflow, productions) %>%
      #Some loFlow categories have several values. Multiply by the proportions before aggregating
      mutate(Productions = Income_Prop * Productions) %>%
      group_by(loFlow, NTM_Zone) %>%
      summarise(Productions = sum(Productions)) %>%
      ungroup
    
    #Return the dataframes
    list(attractions_output = attractions_output, 
         productions_output = productions_output)
  }
  
  # Execute the function in a loop ----------------------------------------
  # Find the files --------------------------------------------------------
  files <- str_c(ctripends_directory, "\\", list.files(ctripends_directory))
  #Remove any file that is not a db file
  files <- files[str_detect(files, "\\.accdb$")]
  years <- str_extract(list.files(ctripends_directory), "\\d\\d\\d\\d") %>%
    as.integer
  results <- list()
  for(i in seq_along(files)){

    #Get data from access and save as csv
    c <- odbcDriverConnect(paste0("Driver={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=", files[i]))
    zonePurp <- sqlFetch(c, "ZonePurpData", stringsAsFactors = F)
    tPhis <- sqlFetch(c, "TPihs", stringsAsFactors = F)
    odbcClose(c)
    
    #Do transformations and save
    transformed <- generate_trip_ends(zonePurp, tPhis)
    write.csv(transformed$attractions_output, str_c(output_dir, "/extracted-attractions-", years[i], ".csv"), row.names = F)
    write.csv(transformed$productions_output, str_c(output_dir, "/extracted-productions-", years[i], ".csv"), row.names = F)
    
    #Make memory available
    rm(transformed, zonePurp, tPhis)
    gc()
  }
  
  # Write a log file --------------------------------
  log_text <- str_c(Sys.time(), " \nCTripEnds directory used: \n", ctripends_directory)
  log_filepath <- str_c(output_dir,"/output log.txt")
  write_lines(log_text, log_filepath)
  

  
  
}



# Interpolate -------------------------------------------------------------



generate_interpolations <- function(output_dir){
  # Interpolate Functions ---------------------------------------------------
  
  interpolate_productions <- function(productions_df, year_interpolate){
    
    a <- filter(productions_df, year == year_interpolate - 4) %>% 
      rename(productions_year1 = Productions) %>%
      select(-year)
    b <- filter(productions_df, year == year_interpolate + 1) %>%
      rename(productions_year2 = Productions) %>%
      select(-year)
    
    inner_join(a,b) %>%
      mutate(increase =  productions_year2 - productions_year1 ) %>%
      mutate(increase_per_year = increase / 5 ) %>%
      mutate(productions_interpolated = productions_year1 + (increase_per_year * 4)) %>%
      select(loFlow, NTM_Zone, Productions = productions_interpolated )
    
  }
  
  interpolate_attractions <- function(attractions_df, year_interpolate){
    
    a <- filter(attractions_df, year == year_interpolate - 4) %>% 
      rename(attractions_year1 = Attractions) %>%
      select(-year)
    b <- filter(attractions_df, year == year_interpolate + 1) %>%
      rename(attractions_year2 = Attractions) %>%
      select(-year)
    
    inner_join(a,b) %>%
      mutate(increase =  attractions_year2 - attractions_year1 ) %>%
      mutate(increase_per_year = increase / 5 ) %>%
      mutate(attractions_interpolated = attractions_year1 + (increase_per_year * 4)) %>%
      select(NTM_Purpose, NTM_Zone, Attractions = attractions_interpolated )
    
  }
  
  # Reload extracted data ---------------------------------------------------
  
  years_ntem <- seq(2011, 2051, 5)
  files_attraction <- str_c(output_dir, "/extracted-attractions-", years_ntem, ".csv")
  files_production <- str_c(output_dir, "/extracted-productions-", years_ntem, ".csv")
  attractions_extracted <- data.frame()
  productions_extracted <- data.frame()
  for(i in seq_along(years_ntem)){
    attractions <- read_csv(files_attraction[i]) %>% mutate(year = years_ntem[i])
    productions <- read_csv(files_production[i]) %>% mutate(year = years_ntem[i])
    attractions_extracted <- rbind(attractions_extracted, attractions)
    productions_extracted <- rbind(productions_extracted, productions)
    rm(attractions, productions)
  }
  
  # Interpolate and write csv's ---------------------------------------------
  years_final = c(2015, 2020, 2025, 2030, 2035, 2040, 2045, 2050)
  for(year in years_final){
    #Productions
    filename <- str_c(output_dir, "/interpolated-productions-", year, ".csv")
    df <- interpolate_productions(productions_extracted, year)
    write.csv(df, filename, row.names = F)
    
    #Attractions
    filename <- str_c(output_dir, "/interpolated-attractions-", year, ".csv")
    df <- interpolate_attractions(attractions_extracted, year)
    write.csv(df, filename, row.names = F)
    
  }
  
}







# Compare -----------------------------------------------------------------
# 
# productions_actual <- read_csv("output/productions-actual.csv") %>% rename(ProductionsAct = Productions)
# attractions_actual <- read_csv("output/attractions-actual.csv") %>% rename(AttractionsAct = Attractions)
# 
# a <- inner_join(productions_output, productions_actual)
# b <- inner_join(attractions_output, attractions_actual)
# 
# 
# a$diff = a$Productions - a$ProductionsAct
# b$diff = b$Attractions - b$AttractionsAct
# 
# 
# a$diffPCT <- (a$diff / a$ProductionsAct)*100
# b$diffPCT <- (b$diff / b$AttractionsAct)*100
# 
# summary(a)
# summary(b)
# 
# arrange(a, diffPCT)
# arrange(a, ProductionsAct)
# 
# #Rounding errors reach 5%  for some categories with low numbers (over 75s in HB Education) (11-100 productions per day)
# 
# colSums(a)
# #Total productions off by 5,000 out of 81,000,000