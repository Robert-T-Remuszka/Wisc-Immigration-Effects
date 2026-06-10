# %% Import some stuff
import re
import pandas as pd
from ipumspy import IpumsApiClient, MicrodataExtract, readers, ddi
from ipumspy import exceptions as ipums_exceptions
from MyCredentials import ApiKeys
from globals import Paths as P
from pathlib import Path

ExtractsDir = Path(P['CensusEx'])

# Connect to API
ipums = IpumsApiClient(ApiKeys['IPUMS'])

# %%
Vars = [
    'BPL',      # Birthplace
    'MBPL',     # Mother's birthplace
    'FBPL',     # Father's birthplace
    'ANCESTR1', # First-declared ancestry
    'ANCESTR2', # Second-declared ancestry
    'CITIZEN',  # Citizenship status
    'YRIMMIG',  # Year of immigration
    'SEX',
    'AGE',
    'RELATE',   # Relation to head of household
    'MARST',    # Marital status
    'LIT',      # Literacy
    'LABFORCE', # Labor force indicator
    'OCC',      # Occupation
    'OCC1950',  # Harmonized 1950 occupation codes
    'IND1950',  # Harmonized 1950 Industry
    'OCCSCORE', # Occupational score
    'SEI',      # Duncan socioeconomic index
    'PRESGL',   # Occupational prestige, Siegel
    'ERSCOR50', # Occupational earnings score (harmonize 1950)
    'EDSCOR50', # Occupational education score (harmonize 1950)
    'NPBOSS50',  # Nam-Powers-Boyd occupational status score (harmonize 1950)
    'RACE'      # Race
]

# Sample list - names of samples in IPUMS can be found at: https://usa.ipums.org/usa-action/samples/sample_ids
Samps = ['us1870a', 'us1880a', 'us1900k', 'us1910k', 'us1920a', 'us1930a'] + ['us' + str(year) + 'a' for year in range(1970,2010,10)]

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


# %%
