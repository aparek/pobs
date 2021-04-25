import json
import pandas as pd
import sys


def main():

    if len(sys.argv) >= 1:

        csv_filename = sys.argv[1] + '_obs_cen.xlsx'
        outfilename = sys.argv[1] + '.BRE'
        orig_bre_filename = sys.argv[1] + '.BRE'
        backup_filename = sys.argv[1] + '.bak'
    else:
        print('No xlsx file provided. Exiting')

    excel_file = pd.read_excel(csv_filename)
    newBreValues = excel_file.to_dict(orient='records')

    with open(orig_bre_filename) as infile:
        data = json.load(infile)

        
    with open(backup_filename, 'w') as outfile:
        json.dump(data, outfile, indent=4, sort_keys=True)

    rawData = data['Data']

    for bre in range(0, data['Header']['count']):
        rawData[bre]['ObsScore'] = newBreValues[bre]['Obstructive']
        rawData[bre]['CentScore'] = newBreValues[bre]['Central']
        rawData[bre]['pobs'] = newBreValues[bre]['pobs']

    data['Data'] = rawData

    with open(outfilename, 'w') as outfile:
        json.dump(data, outfile, indent=4, sort_keys=True)


if __name__ == '__main__':
    main()
