
import string

class retCfg:
    cfg={}
    _readingKey=''
    _readingSubKey=''
    def load_a_line(self, line: str):
        #skip comments
        line=line.strip()
        if line.startswith('#'):
            return
        # key
        if line.startswith('[') and line.endswith(']'):
            line=line[1:len(line)-1]
            arr = line.split('"')
            # print(f"#line: {line}")
            # print(f"#arr({len(arr)}): {arr}")
            for i in range(len(arr)):
                arr[i]=arr[i].strip('.')
                                
            if len(arr)==1:
                if '.' in arr[0]:
                    print("#[WARNING] not supported: " + arr[0])
                else:
                    self._readingKey=arr[0]
                    if not self._readingKey in self.cfg:
                        self.cfg[self._readingKey]={}
            elif len(arr)==3 and arr[2]=='':
                self._readingKey=arr[0]+', '+arr[1]
                self._readingSubKey=''
                if not self._readingKey in self.cfg:
                    self.cfg[self._readingKey]={}
            elif len(arr)==3 and arr[2]!='':
                self._readingKey=arr[0]+', '+arr[1]
                self._readingSubKey=arr[2]
                if not self._readingKey in self.cfg:
                    self.cfg[self._readingKey]={}
                if not self._readingSubKey in self._readingKey:
                    self.cfg[self._readingKey][self._readingSubKey]={}
            else:
                print("[ERROR] load_a_line: bad key -- " + line)
                exit
        #value
        else:
            arr=line.split("=")
            key=arr[0].strip()
            val=arr[1].strip()
            if '#' in val:
                val=val.split('#')[0].strip()
            if self._readingSubKey=='':
                self.cfg[self._readingKey][key]=val
            else:
                self.cfg[self._readingKey][self._readingSubKey][key]=val
        return

    def makeRuntimeExs(self):
        r="import Config\n\n"
        for k,v in self.cfg.items():
            if v == {}:
                print("#[WARNING] skipping empty key: "+k)
                continue
            r=r[:-1] + f"\n\nconfig :{k},"
            for vk,vv in v.items():
                if isinstance(vv, str):
                    r += f"\n  {vk}: {vv},"
                else:
                    r += f"\n  {vk}: [ "
                    for vvk, vvv in vv.items():
                        r += f"{vvk}: {vvv},"
                    r=r[:-1]+"],"

        return r[:-1]


##############
cfg=retCfg()
with open("config.toml") as f:
    for line in f:
        line=line.strip()
        if line =="":
            continue
        cfg.load_a_line(line)
    # print(cfg.cfg)
    print(cfg.makeRuntimeExs())



