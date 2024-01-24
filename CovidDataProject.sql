/*Project to look at the data from the Covid Pandemy and draw some 
meaningfull information from it */

-- First we create de database


DROP DATABASE IF exists  covid_data_project;
CREATE DATABASE covid_data_project;
USE covid_data_project;

/* Create a table to introduce the data from our .csv file since
 the import wizard in mysql is not able to import the amount of 
 data required in an acceptable amount of time */

drop table if exists death_covid_data;
CREATE TABLE death_covid_data (
continent varchar(50),
location varchar(50),
date_ date,
population bigint,
total_cases bigint,
new_cases int,
total_deaths int,
new_deaths int)
;

drop table if exists vaccination_covid_data;
CREATE TABLE vaccination_covid_data (
continent varchar(50),
location varchar(50),
date_ date,
total_vaccinations bigint,
new_vaccinations int)
;

/* You will have to save the .csv in the secure_file_priv folder*/
 
SHOW VARIABLES LIKE "secure_file_priv"
;
SHOW VARIABLES LIKE 'local_infile'
;
SHOW VARIABLES LIKE 'log_error'
;

LOAD DATA INFILE 'DeathCovidData.csv' INTO TABLE death_covid_data
FIELDS TERMINATED BY';'
IGNORE 1 LINES
;

LOAD DATA INFILE 'VaccinationCovidData.csv' INTO TABLE vaccination_covid_data
FIELDS TERMINATED BY';'
IGNORE 1 LINES
;

/* We observe that there is some issue with the all the numerical columns
where a 0 is added at the end, so we create some new columns where we solve
this problem, and we check it works */
 
select population
from death_covid_data
where population like '%9'
;

ALTER TABLE  death_covid_data
add population_fixed varchar(50)
;

update death_covid_data
set population_fixed = substring(population, 1, length(population)-1)
;

ALTER TABLE  death_covid_data
add total_cases_fixed varchar(50),
add new_cases_fixed varchar(50),
add total_deaths_fixed varchar(50),
add new_deaths_fixed varchar(50)
;

update death_covid_data
set total_cases_fixed = substring(total_cases, 1, length(total_cases)-1)
;

update death_covid_data set 
new_cases_fixed = substring(new_cases, 1, length(new_cases)-1),
total_deaths_fixed = substring(total_deaths, 1, length(total_deaths)-1),
new_deaths_fixed = substring(new_deaths, 1, length(new_deaths)-1)
;


select population_fixed
from death_covid_data
where population_fixed like '%5'
;

-- Select Data we will be using 

Select Location, date_, total_cases, new_cases, total_deaths, population
From death_covid_data
Where continent <> ''
order by 1,2
;

-- Ratio Total Cases to Total Deaths 
-- Likelyhood of dying if you contract Covid in a specific counry

Select Location, date_, total_cases,total_deaths, (total_deaths/total_cases)*100 as death_percentage
From death_covid_data
Where location like '%Spain%'
and  continent <> ''
order by 1,2
;

-- Ratio Cases to Population (Infection Rate)
-- Shows what percentage of population was infected by Covid

Select Location, date_, Population, total_cases,  (total_cases/population)*100 as infection_rate
From death_covid_data
Where location like '%spain%'
order by 1,2
;

-- Countries with Highest Infection Rate in history ordered

Select Location, Population_fixed, max(cast(Total_cases_fixed as unsigned)) as highest_infection_count,  Max((total_cases_fixed/population_fixed))*100 as infection_rate
From death_covid_data
Where continent <> ''
Group by Location, Population_fixed
order by infection_rate desc
;

-- Countries with Highest Death Count 

Select Location, max(cast(Total_deaths_fixed as unsigned)) as total_death_count
From death_covid_data
Where continent <> ''
Group by Location
order by total_death_count desc
;

-- BREAKING THINGS DOWN BY CONTINENT

-- Showing contintents with the highest death count 

Select location, max(cast(Total_deaths_fixed as unsigned)) as total_death_count
From death_covid_data
Where continent = ''
Group by location
order by total_death_count desc
;

-- GLOBAL NUMBERS (You can remove the comment on the group statement to see the evolution over time)

Select SUM(new_cases_fixed) as total_cases, SUM(cast(new_deaths_fixed as unsigned)) as total_deaths, SUM(cast(new_deaths_fixed as unsigned))/SUM(New_Cases_fixed)*100 as DeathPercentage
From death_covid_data
Where continent <> '' 
-- group by date_
order by 1,2
;

-- Total Population vs Vaccinations
-- Shows amounts of doses administered per person in each country

Select death.continent, death.location, death.date_, death.population_fixed, vacc.new_vaccinations
, SUM(vacc.new_vaccinations) OVER (Partition by death.location Order by death.location, death.date_) as vaccines_admisnitered
 , (SUM(vacc.new_vaccinations) OVER (Partition by death.location Order by death.location, death.date_)/death.population_fixed) as vaccines_admisnitered_per_person
From covid_data_project.death_covid_data as death
Join covid_data_project.vaccination_covid_data as vacc
	ON death.location = vacc.location
	and death.date_ = vacc.date_
where death.continent <> ''
order by 2,3
;

-- Using CTE to perform Calculation on Partition By in previous query

With vacc_add (continent, Location, Date, Population, new_Vaccinations, vaccines_admisnitered)
as
(
Select death.continent, death.location, death.date_, death.population_fixed, vacc.new_vaccinations
, SUM(vacc.new_vaccinations) OVER (Partition by death.location Order by death.location, death.date_) as vaccines_admisnitered
From covid_data_project.death_covid_data as death
Join covid_data_project.vaccination_covid_data as vacc
	on death.location = vacc.location
	and death.date_ = vacc.date_
where death.continent <> ''
order by 2,3
)
Select *, (vaccines_admisnitered/population) as vaccines_admisnitered_per_person
From vacc_add
;

-- Using Temp Table to perform Calculation on Partition By in previous query

DROP Table if exists vaccines_admisnitered_per_person;
CREATE TEMPORARY Table vaccines_admisnitered_per_person
(
Continent varchar(50),
Location varchar(50),
Date date,
Population bigint,
New_vaccinations bigint,
vaccines_admisnitered bigint
)
;

Insert into vaccines_admisnitered_per_person
Select death.continent, death.location, death.date_, death.population_fixed, vacc.new_vaccinations
, SUM(vacc.new_vaccinations) OVER (Partition by death.location Order by death.location, death.date_) as vaccines_admisnitered
From covid_data_project.death_covid_data as death
Join covid_data_project.vaccination_covid_data as vacc
	on death.location = vacc.location
	and death.date_ = vacc.date_
where death.continent <> ''
order by 2,3
;

Select *, (vaccines_admisnitered/Population) AS vaccines_admisnitered_per_person
From vaccines_admisnitered_per_person
;

-- Creating View to store data for later visualizations

Create View vaccines_admisnitered_per_person as
Select death.continent, death.location, death.date_, death.population_fixed, vacc.new_vaccinations
, SUM(vacc.new_vaccinations) OVER (Partition by death.location Order by death.location, death.date_) as vaccines_admisnitered
 , (SUM(vacc.new_vaccinations) OVER (Partition by death.location Order by death.location, death.date_)/death.population_fixed) as vaccines_admisnitered_per_person
From covid_data_project.death_covid_data as death
Join covid_datavaccines_admisnitered_per_person_project.vaccination_covid_data as vacc
	ON death.location = vacc.location
	and death.date_ = vacc.date_
where death.continent <> ''
;
