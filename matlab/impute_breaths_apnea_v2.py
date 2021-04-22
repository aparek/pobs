import json
import sys
import copy
import math


def updateBreathNumbers(newRawData):
    j = 1
    for bre in newRawData:
        bre['BreathId'] = j
        j = j + 1
    return newRawData


def main():

    if len(sys.argv) >= 1:

        outfilename = sys.argv[1] + '.BRE'
        orig_bre_filename = sys.argv[1] + '.BRE'
        backup_filename = sys.argv[1] + '-org.bak'
    else:
        print('Breath table not provided')

    with open(orig_bre_filename) as infile:
        data = json.load(infile)

    with open(backup_filename, 'w') as outfile:
        json.dump(data, outfile, indent=4, sort_keys=True)

    rawData = data['Data']

    for bre in rawData:
        if 15 < bre['Ttot'] < 120 and bre['BreathId'] > 10:

            breathId = bre['BreathId']
            num_breaths_to_impute = math.floor(bre['Ttot'] * ((rawData[breathId - 3]['RespRate'] + rawData[breathId - 2]['RespRate']) / 120.0))
            if not num_breaths_to_impute:
                continue
            else:
                dur_breath = float(bre['Ttot'] / num_breaths_to_impute)

            for j in range(0, num_breaths_to_impute):
                rawData.append(copy.deepcopy(bre))
                rawData[-1]['Ti'] = dur_breath / 2.0
                rawData[-1]['TiTot'] = 0.5
                rawData[-1]['Ttot'] = dur_breath
                rawData[-1]['ElapsedTime'] = int(bre['ElapsedTime'] + j*dur_breath*bre['Frequency'] + 1)
                rawData[-1]['BreathId'] = int(0)
                rawData[-1]['FlowAvgMid3rdPercentNormal'] = float(0.0)


    data['Header']['count'] = len(rawData)

    with open(outfilename, 'w') as outfile:
        json.dump(data, outfile, indent=4, sort_keys=False)


if __name__ == '__main__':
    main()
