p1 = r"c:\Users\ardce\OneDrive\Desktop\Sinif360_Magaza_Gorselleri\Magaza_Vitrin_Onizleme.html"
p2 = r"c:\Users\ardce\OneDrive\Desktop\Sinif360_Magaza_Tasarimlari\Magaza_Vitrin_Onizleme.html"

with open(p1, "r", encoding="utf-8") as f:
    c = f.read()

c = c.replace("./0", "../Sinif360_Magaza_Gorselleri/0")
for i in range(1, 10):
    c = c.replace(f"'{i:02d}_", f"'../Sinif360_Magaza_Gorselleri/{i:02d}_")

with open(p2, "w", encoding="utf-8") as f:
    f.write(c)

print("Synchronized Magaza_Vitrin_Onizleme.html successfully.")
