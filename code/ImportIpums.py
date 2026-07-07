# %% ################################ Import some stuff ################################
import re
import pandas as pd
from ipumspy import IpumsApiClient, MicrodataExtract, readers, ddi
from ipumspy import exceptions as ipums_exceptions
from MyCredentials import ApiKeys
from globals import Paths as P
from pathlib import Path

ExtractsDir = Path(P['CensusEx'])

# %% ################################ ONLY RUN THIS SECTION IF YOU NEED TO EDIT THE ORIGINAL EXTRACTS ################################

# Connect to API
ipums = IpumsApiClient(ApiKeys['IPUMS'])

# Clear any previous extract files before re-running
for f in ExtractsDir.glob('*.xml'): f.unlink()
for f in ExtractsDir.glob('*.gz'):  f.unlink()

Vars = [
    'BPL',      # Birthplace
    'MBPL',     # Mother's birthplace
    'FBPL',     # Father's birthplace
    'ANCESTR1', # First-declared ancestry
    'ANCESTR2', # Second-declared ancestry
    'CITIZEN',  # Citizenship status
    'YRIMMIG',  # Year of immigration
    'MIGPLAC5', # STATE or country of residence 5Y ago
    'STATEFIP', 
    'STATEICP', 
    'COUNTYICP',
    'COUNTYFIP',
    'COUNTYNHG', 
    'CNTYGP97', 
    'CNTYGP98',
    'PUMA'
]

# Sample list - names of samples in IPUMS can be found at: https://usa.ipums.org/usa-action/samples/sample_ids
# I download the same sample as Burchardi et. al. (2019), see table 1 in the appendix
Samps = [
    'us1880d',
    'us1900j',
    'us1910k',
    'us1920a',
    'us1930b',
    'us1940a',
    'us1950a',
    'us1970c',
    'us1980a',
    'us1990a',
    'us2000a',
    'us2010a'
]

# Loop through these sample and create extracts
for samp in Samps:

    print('Creating and downloading extract for sample id: ' + samp)

    samp_vars = Vars.copy()
    while True:
        try:
            extract = MicrodataExtract('usa', [samp], samp_vars)
            ipums.submit_extract(extract)
            ipums.wait_for_extract(extract)
            ipums.download_extract(extract, download_dir=ExtractsDir)
            break
        except ipums_exceptions.BadIpumsApiRequest as e:
            unavailable = re.findall(r'^(\w+): This variable is not available', str(e), re.MULTILINE)
            if not unavailable:
                raise
            print(f'Sample {samp}: dropping unavailable variables: {unavailable}')
            samp_vars = [v for v in samp_vars if v not in unavailable]


# %% ################################ SAVE EACH OF THE EXTRACTS AS DTA ################################

# Create a list of files to read through
Files = list(ExtractsDir.glob("*.xml"))

# Loop through files and save as stata dta
for f in Files:

    ddi = readers.read_ipums_ddi(f)
    df  = readers.read_microdata(ddi, ExtractsDir / ddi.file_description.filename)

    print('\n*************************************************************\n' +
          f'Saving file {f}, sample ' + str(df['YEAR'][0]) +
          '\n*************************************************************\n')
    
    name = 'Acs' + str(df['YEAR'][0]) + '.dta'
    df.to_stata(ExtractsDir / name, write_index = False)


# %% ################################ CROSS-SECTIONAL EXTRACTS: 1930 & 2000 INDIVIDUAL OUTCOMES ################################
# These extracts add individual-level outcome variables (wages, occupation scores, demographics)
# needed for the individual-effects regressions, on top of the same geographic/origin variables
# used in the county-flow extracts above.

CrossSectionDir = Path(P['CrossSectionEx'])
CrossSectionDir.mkdir(parents=True, exist_ok=True)

# Clear any previous extract files before re-running
for f in CrossSectionDir.glob('*.xml'): f.unlink()
for f in CrossSectionDir.glob('*.gz'):  f.unlink()

CrossSectionVars = Vars + [
    'INCWAGE',  # Wage and salary income
    'SEX',
    'RACE',
    'AGE',
    'OCCSCORE', # Occupational income score
    'SEI',      # Duncan Socioeconomic Index - complements OCCSCORE
    'OCC1950',  # Occupation, harmonized to the 1950 classification for comparability across census years
    'IND1950',  # Industry, harmonized to the 1950 classification for comparability across census years
    'EDUC',     # Educational attainment
    'CLASSWKR', # Class of worker (wage/salary vs. self-employed) - needed to restrict to workers for whom INCWAGE is meaningful
    'EMPSTAT',  # Employment status
    'UHRSWORK', # Usual hours worked per week
    'WKSWORK1'  # Weeks worked last year
]

CrossSectionSamps = [
    'us1930b',
    'us2000a'
]

# Loop through these samples and create extracts
for samp in CrossSectionSamps:

    print('Creating and downloading cross-section extract for sample id: ' + samp)

    samp_vars = CrossSectionVars.copy()
    while True:
        try:
            extract = MicrodataExtract('usa', [samp], samp_vars)
            ipums.submit_extract(extract)
            ipums.wait_for_extract(extract)
            ipums.download_extract(extract, download_dir=CrossSectionDir)
            break
        except ipums_exceptions.BadIpumsApiRequest as e:
            unavailable = re.findall(r'^(\w+): This variable is not available', str(e), re.MULTILINE)
            if not unavailable:
                raise
            print(f'Sample {samp}: dropping unavailable variables: {unavailable}')
            samp_vars = [v for v in samp_vars if v not in unavailable]


# %% ################################ SAVE EACH OF THE CROSS-SECTION EXTRACTS AS DTA ################################

CrossSectionFiles = list(CrossSectionDir.glob("*.xml"))

for f in CrossSectionFiles:

    ddi = readers.read_ipums_ddi(f)
    df  = readers.read_microdata(ddi, CrossSectionDir / ddi.file_description.filename)

    print('\n*************************************************************\n' +
          f'Saving file {f}, sample ' + str(df['YEAR'][0]) +
          '\n*************************************************************\n')

    name = 'Acs' + str(df['YEAR'][0]) + '.dta'
    df.to_stata(CrossSectionDir / name, write_index = False)


# %%
