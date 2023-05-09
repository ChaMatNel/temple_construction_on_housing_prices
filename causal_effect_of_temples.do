***** Do File for Temple Project *****

*Setting file directory
cd "D:\chad_adrienne_research_project"

*Pre-Processing and data cleaning
********************************************************************************
*Importing distances from temple data we gather from ArcGIS and preparing it for merge
import delimited "D:\chad_adrienne_research_project\distances.csv"
rename rowid_ RowID
save distances, replace
clear

*Importing population and temples data and saving them as .dta
import delimited "D:\chad_adrienne_research_project\az_county_pop.csv"
rename county County
save az_county_pop, replace
clear
import delimited "D:\chad_adrienne_research_project\temples.csv"
save temples, replace

*importing a csv of missing values we collected from zillow
clear
import delimited "D:\chad_adrienne_research_project\missing_values.csv", case(preserve)
save missing_values, replace
clear

*Import main data set
use "D:\chad_adrienne_research_project\housing_data_Adrienne_Chad.dta"

*Merge distances from temple data with main data set
drop _merge
merge m:1 RowID using distances

*Merge missing values into main data set
drop _merge
merge 1:1 RowID using missing_values, update replace force

*Merge temple charactersitics data with main data set
drop _merge
merge m:1 near_fid using temples

*Dropping houses that don't correspond to a temple and that aren't within 2 miles of a temple
drop if near_dist ==-1
replace near_dist = near_dist/5280
drop if near_dist >=2

*Creating a within_radius dummy that will indicate treatment and a control_1 dummy to indicate our primary control group
gen within_radius = 0
replace within_radius =1 if near_dist <= .75
gen control_1 =0
replace control_1 =1 if near_dist <=1.25 & near_dist >.75

*Convert time stamps and create days from dedication variables
generate sale_date = date(RecordingDate,"YMD")
generate ded_date = date(dedication_date,"YMD")
generate days_fr_ded = sale_date - ded_date

*Gen time periods. Treatment occurs between periods 3 & 4
gen period = 0
replace period = 1 if days_fr_ded <=-730 & days_fr_ded > -1095
replace period = 2 if days_fr_ded <=-365 & days_fr_ded > -730
replace period = 3 if days_fr_ded <=0 & days_fr_ded > -365
replace period = 4 if days_fr_ded <=365 & days_fr_ded > 0
replace period = 5 if days_fr_ded <=730 & days_fr_ded > 365
replace period = 6 if days_fr_ded <=1095 & days_fr_ded > 730

*Create dummy variables for post and pre treatment
gen post = 0
gen pre = 0
replace pre =1 if period >=1 & period <=3
replace post  = 1 if period >=4 & period <=6

*Dropping houses that don't fall in treatment or post time periods
drop if period ==0

*Drop houses with no selling price or 0 selling price
drop if SalesPriceAmount ==0 | SalesPriceAmount == .

*Drop outliers in main data set (Homes with Sales Prices way above what is normal)
scatter SalesPriceAmount near_fid
drop if SalesPriceAmount > 5000000
scatter SalesPriceAmount near_fid
drop if SalesPriceAmount >2000000

*Drop observations with missing control data
drop if YearBuilt ==.
drop if LotSizeAcres ==.
drop if TotalBathPlumbingFixtures ==.
drop if BuildingAreaSqFt ==.

*We are going to drop all the snowflake temple data because there are no pre-treatment observations :(
drop if near_fid==1

*Merging population data
drop _merge
merge m:1 County year using az_county_pop
rename population county_pop
drop if _merge ==2
drop _merge

*Dropping columns that aren't needed for regression and analysis
drop ImportParcelID PropertyFullStreetAddress PropertyState CensusTract NoOfBuildings LoadID PropertyAddressTractAndBlock NoOfUnits PropertyCountyLandUseDescription PropertyLandUseStndCode EffectiveYearBuilt YearRemodeled TotalKitchens ThreeQuarterBath HalfBath QuarterBath BathSourceStndCode RoofStructure FoundationTypeStndCode ElevatorStndCode FireplaceFlag FirePlaceTypeStndCode FireplaceNumber WaterStndCode WaterStndCode SewerStndCode TimeshareStndCode StoryTypeStndCode TransId DataClassStndCode DocumentTypeStndCode DocumentDate SignatureDate EffectiveDate PartialInterestTransferStndCode SalesPriceAmountStndCode IntraFamilyTransferFlag TransferTaxExemptFlag PropertyUseStndCode AssessmentLandUseStndCode OccupancyStatusStndCode LoanAmount LoanAmountStndCode PropertySequenceNumber time oid_ propertyfullstreetaddress propertycity propertyaddresslatitude propertyaddresslongitude TotalActualBathCount

*Creating Y variable
gen lnSalesPriceAmount = ln(SalesPriceAmount)

*Creating post-treatment interaction terms
gen treatpost = within_radius*post
gen control_1_post = control_1*post

*Summary statistics
********************************************************************************
*Summary Statistics for all temples
*Stats for control group pre treatment
tabstat SalesPriceAmount YearBuilt LotSizeAcres BuildingAreaSqFt TotalBathPlumbingFixtures if (within_radius ==0 & post ==0), by(temple) stat(mean, count)
*Stats for control goup post-treatment
tabstat SalesPriceAmount YearBuilt LotSizeAcres BuildingAreaSqFt TotalBathPlumbingFixtures if (within_radius ==0 & post ==1), by(temple) stat(mean, count)
*Stats for treatment group pre treatment
tabstat SalesPriceAmount YearBuilt LotSizeAcres BuildingAreaSqFt TotalBathPlumbingFixtures if (within_radius ==1 & post ==0), by(temple) stat(mean, count)
*Stats for treatment group post treatment
tabstat SalesPriceAmount YearBuilt LotSizeAcres BuildingAreaSqFt TotalBathPlumbingFixtures if (within_radius ==1 & post ==1), by(temple) stat(mean, count)

*gen group variable to generate summary stats by group
gen group =0
replace group=1 if within_radius==1
replace group=2 if control_1 ==1
replace group=3 if control_1 ==0 & within_radius==0

*Additional Summary statistics for just Gilbert area (includes 2nd control radius)
*pre-treatment
tabstat SalesPriceAmount YearBuilt LotSizeAcres BuildingAreaSqFt TotalBathPlumbingFixtures if near_fid==3 & post==0, by(group) stat(mean, count)
*post-treatment
tabstat SalesPriceAmount YearBuilt LotSizeAcres BuildingAreaSqFt TotalBathPlumbingFixtures if near_fid==3 & post==1, by(group) stat(mean, count)

*Regression and Results
********************************************************************************
*import package to export regression resluts
ssc install outreg2

*Regression control = .75-1.25 miles
xi: reg lnSalesPriceAmount LotSizeAcres YearBuilt TotalBathPlumbingFixtures BuildingAreaSqFt county_pop i.year within_radius treatpost if near_fid ==3 & near_dist < 1.25, robust

outreg2 using results_gilbert, word
*Regression control_1 = .75-1.25 & control 2 = 1.25-2 miles
xi: reg lnSalesPriceAmount LotSizeAcres YearBuilt TotalBathPlumbingFixtures BuildingAreaSqFt county_pop i.year within_radius treatpost control_1 control_1_post if near_fid ==3, robust

outreg2 using results_gilbert, word

*Regression control =.75-2 miles
xi: reg lnSalesPriceAmount LotSizeAcres YearBuilt TotalBathPlumbingFixtures BuildingAreaSqFt county_pop i.year within_radius treatpost if near_fid ==3, robust

outreg2 using results_gilbert, word

*Calculating residuals
predict y_resid, resid

*Save uncollapsed data_final
save final_dataset_clean, replace

*Summary plots and visualizations
********************************************************************************
*Collapse data to make line plots for parallel trends check
collapse lnSalesPriceAmount y_resid, by (period near_fid within_radius control_1)
save data_collapsed_3, replace

*Graphing parallel trends for Gilbert, Phoenix, and Tucson
twoway (line lnSalesPriceAmount period if near_fid==2 & control_1==1, lpattern(dash) lcolor(red)) (line lnSalesPriceAmount period if near_fid==2 & within_radius==1, lcolor(red)) (line lnSalesPriceAmount period if near_fid==3 & control_1==1, lpattern(dash) lcolor(blue)) (line lnSalesPriceAmount period if near_fid==3 & within_radius==1, lcolor(blue)) (line lnSalesPriceAmount period if near_fid==5 & control_1==1, lpattern(dash)  lcolor(green)) (line lnSalesPriceAmount period if near_fid==5 & within_radius==1, lcolor(green)), ytitle("Log Sales Price") title("Housing Prices Before and After Temple Dedication") xline(3)

*Parallel trends plot for Gilbert Arizona
twoway (line lnSalesPriceAmount period if near_fid==3 & within_radius==1, lcolor(black) legend(label(1 "0-.75 Miles"))) (line lnSalesPriceAmount period if near_fid==3 & control_1==1, lpattern(dash) lcolor(blue) legend(label(2 ".75-1.25 Miles"))), ytitle("Log Sales Price") title("Housing Prices Before & After Gilbert Temple Dedication") xline(3)

*Parallel trends plot for Gilbert Arizona
twoway (line lnSalesPriceAmount period if near_fid==3 & within_radius==1, lcolor(black) legend(label(1 "0-.75 Miles"))) (line lnSalesPriceAmount period if near_fid==3 & control_1==1, lpattern(dash) lcolor(blue) legend(label(2 ".75-1.25 Miles"))) (line lnSalesPriceAmount period if near_fid==3 & (control_1==0 & within_radius==0), lpattern(dash) lcolor(green) legend(label(3 "1.25-2 Miles"))),ytitle("Log Sales Price") title("Housing Prices Before & After Gilbert Temple Dedication") xline(3)

*Residuals plot of regression
twoway (line y_resid period if near_fid==3 & control_1==1, lpattern(dash) lcolor(blue) legend(label(1 ".75-1.25 Miles"))) (line y_resid period if near_fid==3 & within_radius==1, lcolor(blue) legend(label(2 "0-.75 Miles"))),ytitle("Residuals From Log Price Regression") title("Residual Plot of Log Price Regression ") xline(3)

*The End