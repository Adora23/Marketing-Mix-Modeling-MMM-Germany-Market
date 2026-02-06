import pandas as pd

# Load the excel file
df = pd.read_excel("online_retail_II.xlsx")

# Quick sanity check
print(df.head())
print(df.info())
