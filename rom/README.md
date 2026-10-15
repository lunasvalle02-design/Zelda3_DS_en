# ROM

Place your US ROM of *The Legend of Zelda: A Link to the Past* in this folder as **`zelda3.sfc`**.

| | |
|:--|:--|
| **Expected file** | `rom/zelda3.sfc` |
| **Expected SHA-256** | `66871d66be19ad2c34c927d6b14cd8eb6fc3181965b6e517cb361f7316009cfb` |

The ROM is only used to generate `build/zelda3_assets.dat`:

```bash
make -f zelda3ds.mk assets        # Linux / WSL
.\build.ps1 assets                # Windows
```

> [!CAUTION]
> This folder is listed in `.gitignore`. The ROM must **never** be committed to the repository or
> included in a distributed package.
