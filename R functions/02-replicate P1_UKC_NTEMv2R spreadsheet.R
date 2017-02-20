generate_ulc_files <- function(output_dir, ulc_type = "policy"){
  require(gdata)
  # Function to create a ulc file that can be iterated over -----------------
  generate_ulc_file <- function(output_dir, ulc_type, year){
    # ulc_type is "base" or "policy"
    # year is a integer and corresponds to the filename
    # output_dir is the path of the directory containing the transformed and interpolated
    #  productions and attractions and where the current files will be outputted
    # file_name is the name of the current file to be written
    
    
    # Constants ---------------------------------------------------------------
    #These constants were listed on the definitions tab of the spreadsheet
    #And lookups the format of the DBconstraint tables
    
    AttrBase <- 1509
    ProdBase <- 1400
    
    lookup_DBconstraint_pivot <- read_csv("lookups/ULC DBconstraint pivot.csv")
    lookup_DBconstraint <- read_csv("lookups/ULC DBconstraint.csv")
    
    file_out <- str_c(output_dir, "/ULC-", ulc_type, "-", year, ".dat")
    
    
    # Import productions and attractions --------------------------------------
    
    if(year == 2011){
      file_input_attr <- str_c(output_dir,"/extracted-attractions-2011.csv")
      file_input_prod <- str_c(output_dir,"/extracted-productions-2011.csv")
    } else{
      file_input_attr <- str_c(output_dir, "/interpolated-attractions-", year, ".csv")
      file_input_prod <- str_c(output_dir, "/interpolated-productions-", year, ".csv")
    }
    
    
    input_attr <- read_csv(file_input_attr)
    input_prod <- read_csv(file_input_prod)
    
    
    # Replicate DBconstraint tab ----------------------------------------------
    
    DBconstraint_pivot_table <- inner_join(lookup_DBconstraint_pivot, input_prod,
                                           by = c("loFlow", "NTM_Zone")) %>%
      group_by(PurpDef, hhDef) %>%
      summarise(Total = sum(Productions)) %>%
      ungroup %>%
      arrange(PurpDef, hhDef)
    #Currently the pivot table is sorted alphabetically
    #Rearrange to sort the same order as in the excel sheet
    custom_sort_order <- c(22,23,24,25,26,
                           1, 2, 3, 4, 5, 
                           6, 7, 8, 9, 10,
                           12,13,14,15,16,
                           17,18,19,20,21,
                           11, 27, 28)
    
    DBconstraint_pivot_table <- DBconstraint_pivot_table[custom_sort_order,] %>%
      mutate(Index = seq(1,28))
    
    DBconstraint <- left_join(lookup_DBconstraint, DBconstraint_pivot_table,
                              by = "Index") %>%
      mutate(Trips = Total * Dbprop) %>%
      select(Factor, Trips)
    
    
    # Sheet ULC(1) ------------------------------------------------------------
    ulc1_part1 <- input_attr %>%
      mutate(` Fact` = NTM_Purpose + AttrBase,
             Fnct = 15,
             `MinProd.` = round(Attractions),
             `MaxProd.` = round(Attractions),
             ProdUpBd = "1.00E+15", 
             Zone = NTM_Zone, 
             N = "X") %>%
      select(` Fact`, Fnct, `MinProd.`, `MaxProd.`, ProdUpBd, Zone, N) %>%
      arrange(` Fact`, Zone)
    
    #The table changes in the spreadsheet below row 122
    ulc1_part2 <- DBconstraint %>%
      mutate(` Fact` = Factor,
             Fnct = 15,
             `MinProd.` = round(Trips),
             `MaxProd.` = round(Trips),
             ProdUpBd = "1.00E+15",
             Zone = NA,
             N = "X") %>%
      select(` Fact`, Fnct, `MinProd.`, `MaxProd.`, ProdUpBd, Zone, N) %>%
      arrange(` Fact`)
    
    # Sheet ULC(2) ------------------------------------------------------------
    
    lookup_ProdSize <- ulc1_part1[1:15, c("Zone", "MinProd.")] %>%
      rename(ProdSize = `MinProd.`)
    
    ulc2 <- input_prod %>%
      mutate(` Fact` = loFlow + ProdBase,
             Zone = NTM_Zone,
             ExogProd = round(Productions),
             ExogCons = NA,
             ExogChrg = NA,
             ProdAttr = NA,
             `ImpAttr.` = NA) %>%
      arrange(` Fact`, Zone) %>%
      left_join(lookup_ProdSize, by = "Zone") %>%
      select(` Fact`, Zone, ExogProd, ExogCons, ExogChrg, ProdAttr, `ImpAttr.`, ProdSize)
    
    
    
    # Output File -------------------------------------------------------------
    
    ulc_text <- " -----------------------------------------------------------------------
    Study : EM2.0
    File  : Exogenous Changes
    -----------------------------------------------------------------------
    Id. Source......... Gen.Date.. Gen.Time..               Policy.... Year
    ULC P1_ULC_V20.XLS                                      1
    00000000000000000000000000000000000000000000000000000000000000000000000
    PRODUCTION CONSTRAINTS"
    
    write(ulc_text, file_out, append=FALSE)
    
    
    col_widths <- c(5, 4, 9, 9, 8, 4, 1)
    write.fwf(as.data.frame(ulc1_part1), file = file_out, width = col_widths, append = TRUE)
    
    if(ulc_type == "base"){
      ulc_text <- "!Studywide Distance Band constraints"
      write(ulc_text, file_out, append=TRUE)
      write.fwf(as.data.frame(ulc1_part2), file = file_out, width = col_widths, colnames = FALSE, append = TRUE)
    }
    
    ulc_text <- " 00000000000000000000000000000000000000000000000000000000000000000000000
    CHANGES IN ZONAL CHARACTERISTICS"
    write(ulc_text,file=file_out, append=TRUE)
    
    col_widths <- names(ulc2) %>% str_length()
    write.fwf(as.data.frame(ulc2), file_out, width = col_widths, append = TRUE)
    
    ulc_text <- " 00000000000000000000000000000000000000000000000000000000000000000000000
    STUDY-WIDE INCREMENTS AND DECREMENTS
    Fact ExogProd ExogCons MinProd. MaxProd.
    00000000000000000000000000000000000000000000000000000000000000000000000
    00000000000000000000000000000000000000000000000000000000000000000000000"
    write(ulc_text,file=file_out,append=TRUE)
  }
  
  # # Testing -----------------------------------------------------------------
  # 
  # generate_ulc_file("test1.dat", "policy", 2011)
  # generate_ulc_file("test2.dat", "base", 2035)
  
  
  #Iterate over the function for every year --------------------------------
  years <- c(2011, 2015, 2020, 2025, 2030, 2035, 2040, 2045, 2050)
  for(year in years){
    generate_ulc_file(output_dir, ulc_type, year)
  }
}











  
  

