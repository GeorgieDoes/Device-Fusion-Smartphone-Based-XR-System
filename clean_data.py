import pandas as pd

path = input("Enter file path of data: ")
df = pd.read_csv(path,skiprows=1, header=None)
change_detector = (df[0] != df[0].shift()).cumsum()
test_arrays = [group.values for _, group in df.groupby(change_detector)]

for index, test_data in enumerate(test_arrays):
    test_name = test_data[0][0]
    total_rows = len(test_data)
    
    actual_fps_col = test_data[:, 3].astype(float)
    latency_col = test_data[:, 4].astype(float)
    
    mean_fps = actual_fps_col.mean()
    std_fps = actual_fps_col.std()
    
    mean_latency = latency_col.mean()
    std_latency = latency_col.std()
    
    print(f"\n=========================================")
    print(f"TEST {index + 1}: {test_name} ({total_rows} rows)")
    print(f"=========================================")
    print(f"Actual FPS:")
    print(f"  - Mean:               {mean_fps:.2f}")
    print(f"  - Standard Deviation: {std_fps:.2f}")
    print(f"Latency:")
    print(f"  - Mean:               {mean_latency:.2f}")
    print(f"  - Standard Deviation: {std_latency:.2f}")