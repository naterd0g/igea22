#script for group 3 WS data analysis
#libraries and wd----
library(dplyr)
library(readxl)
library(tidyr)
library(stringr)
library(fuzzyjoin)
library(gmt)
library(rgdal)
library(sf)

setwd('/Users/Oskar/Documents/UMass/IGEA/igea22/')

WS3_1 = read_xlsx('Raw_water_data/3WS.1.xlsx')
WS3_2= read_xlsx('Raw_water_data/3WS.2.xlsx')

#mine
#clean up----
WS3_clean1=WS3_1%>%
  select('Line', 'd(18_16)Mean', 'd(D_H)Mean', 'Ignore', 'Identifier_1', 'Identifier_2')%>%
  rename("meanO"="d(18_16)Mean")%>%
  rename("meanH"="d(D_H)Mean")%>%
  filter(Line >= 160)%>%
  filter(Line <= 255)%>%
  filter(Ignore == 0)

WS3_clean2=WS3_2%>%
  select('Line', 'd(18_16)Mean', 'd(D_H)Mean', 'Ignore', 'Identifier_1', 'Identifier_2')%>%
  rename("meanO"="d(18_16)Mean")%>%
  rename("meanH"="d(D_H)Mean")%>%
  filter(Line >= 28)%>%
  filter(Line <= 123)%>%
  filter(Ignore == 0)

#create df for normalizing----
WS3_stand1=WS3_clean1%>%
  filter(Identifier_2 == "standard")%>%
  mutate(standardO=case_when(Identifier_1 == "Picarro zero 1 6_23_22" | Identifier_1 == "Picarro zero 2 6_23_22" | Identifier_1 == "Picarro zero 3 6_23_22"~.3,
                             Identifier_1 == "Picarro mid 3 6_23_22" | Identifier_1 == "Picarro mid 2 6_23_22"| Identifier_1 == "Picarro mid 1 6_23_22"~-20.6,
                             Identifier_1 == "Picarro depl 3 6_23_22" | Identifier_1 == "Picarro depl 2 6_23_22"| Identifier_1 == "Picarro depl 1 6_23_22"~-29.6,))%>%
  mutate(standardH=case_when(Identifier_1 == "Picarro zero 1 6_23_22" | Identifier_1 == "Picarro zero 2 6_23_22" | Identifier_1 == "Picarro zero 3 6_23_22"~1.8,
                             Identifier_1 == "Picarro mid 3 6_23_22" | Identifier_1 == "Picarro mid 2 6_23_22"| Identifier_1 == "Picarro mid 1 6_23_22"~-159,
                             Identifier_1 == "Picarro depl 3 6_23_22" | Identifier_1 == "Picarro depl 2 6_23_22"| Identifier_1 == "Picarro depl 1 6_23_22"~-235,))

WS3_stand2=WS3_clean2%>%
  filter(Identifier_2 == "standard")%>%
  mutate(standardO=case_when(Identifier_1 == "Picarro zero 1 6_23_22" | Identifier_1 == "Picarro zero 2 6_23_22" | Identifier_1 == "Picarro zero 3 6_23_22"~.3,
                             Identifier_1 == "Picarro mid 3 6_23_22" | Identifier_1 == "Picarro mid 2 6_23_22"| Identifier_1 == "Picarro mid 1 6_23_22"~-20.6,
                             Identifier_1 == "Picarro depl 3 6_23_22" | Identifier_1 == "Picarro depl 2 6_23_22"| Identifier_1 == "Picarro depl 1 6_23_22"~-29.6,))%>%
  mutate(standardH=case_when(Identifier_1 == "Picarro zero 1 6_23_22" | Identifier_1 == "Picarro zero 2 6_23_22" | Identifier_1 == "Picarro zero 3 6_23_22"~1.8,
                             Identifier_1 == "Picarro mid 3 6_23_22" | Identifier_1 == "Picarro mid 2 6_23_22"| Identifier_1 == "Picarro mid 1 6_23_22"~-159,
                             Identifier_1 == "Picarro depl 3 6_23_22" | Identifier_1 == "Picarro depl 2 6_23_22"| Identifier_1 == "Picarro depl 1 6_23_22"~-235,))

#linear regressions----
modelO_1 = lm(formula = standardO ~ meanO, data = WS3_stand1)
modelH_1 = lm(formula = standardH ~ meanH, data = WS3_stand1)

modelO_2 = lm(formula = standardO ~ meanO, data = WS3_stand2)
modelH_2 = lm(formula = standardH ~ meanH, data = WS3_stand2)

#create normalized df----
WS3_norm1=WS3_clean1%>%
  filter(Identifier_2=="sample")%>%
  mutate(normO=modelO_1$coefficients[2]*meanO+modelO_1$coefficients[1])%>%
  mutate(normH=modelH_1$coefficients[2]*meanH+modelH_1$coefficients[1])

WS3_norm2=WS3_clean2%>%
  filter(Identifier_2=="sample")%>%
  mutate(normO=modelO_2$coefficients[2]*meanO+modelO_2$coefficients[1])%>%
  mutate(normH=modelH_2$coefficients[2]*meanH+modelH_2$coefficients[1])

WS3_norm=rbind(WS3_norm1,WS3_norm2)

#average isotope ratios and join with metadata----
WS3_avg = WS3_norm%>%
  group_by(Identifier_1)%>%
  summarize(avgO=mean(normO),avgH=mean(normH))

metadata3 = read_xlsx('Raw_water_data/3metadata.xlsx')%>%
  mutate(newtime = sapply(strsplit(as.character(Sample_Time), " "),"[",2))%>%
  mutate(newdate = paste(Date, newtime, sep = " "))%>%
  mutate(date_time=as.POSIXct(newdate,tz="US/Alaska"))%>%
  mutate(doy=as.numeric(strftime(date_time, format = "%j")))

our3 = left_join(WS3_avg,metadata3,"Identifier_1")

saveRDS(our3,'water_scripts/our3.rds')