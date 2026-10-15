// Windows x64 external graphics collector; no game input or persistent system settings.
using System;
using System.Runtime.InteropServices;
using System.Threading;

namespace CarRcCapture {
    public sealed class CaptureReport {
        public uint StartExit, QueryExit, StopExit, Mode, EventsLost, BuffersLost, BuffersWritten;
        public uint[] EnableExits = new uint[5];
        public string Error;
        public CaptureReport() {
            StartExit=QueryExit=StopExit=UInt32.MaxValue;
            for(int i=0;i<EnableExits.Length;i++)EnableExits[i]=UInt32.MaxValue;
        }
    }
    public static class IndependentEtw {
        public const string SessionName = "CarRC4IndependentGraphicsCapture";
        const int PropertyBytes = 4216, NameOffset = 120, FileOffset = 2168;
        const uint Independent = 0x08000000, Sequential = 1, IgnoreKeywordZero = 0x10;
        [DllImport("advapi32.dll", EntryPoint="StartTraceW", CharSet=CharSet.Unicode)]
        static extern uint Start(out ulong handle, string name, IntPtr properties);
        [DllImport("advapi32.dll", EntryPoint="ControlTraceW", CharSet=CharSet.Unicode)]
        static extern uint Query(ulong handle, string name, IntPtr properties, uint code);
        [DllImport("advapi32.dll", EntryPoint="StopTraceW", CharSet=CharSet.Unicode)]
        static extern uint Stop(ulong handle, string name, IntPtr properties);
        [DllImport("advapi32.dll", EntryPoint="EnableTraceEx2")]
        static extern uint Enable(ulong handle, ref Guid provider, uint code, byte level,
            ulong any, ulong all, uint timeout, IntPtr parameters);
        [StructLayout(LayoutKind.Sequential)]
        struct EnableParameters {
            public uint Version, EnableProperty, ControlFlags;
            public Guid SourceId;
            public IntPtr FilterDescriptor;
            public uint FilterCount;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct FilterDescriptor { public ulong Pointer; public uint Size, Type; }
        static void WriteString(IntPtr properties, int offset, string value) {
            if (value.Length >= 1024) throw new ArgumentException("ETW path/name exceeds 1023 characters");
            var bytes = System.Text.Encoding.Unicode.GetBytes(value + "\0");
            Marshal.Copy(bytes, 0, IntPtr.Add(properties, offset), bytes.Length);
        }
        static uint Read(IntPtr p, int offset) { return unchecked((uint)Marshal.ReadInt32(p, offset)); }
        static void Statistics(CaptureReport r, IntPtr p) {
            r.Mode=Read(p,64); r.EventsLost=Read(p,88); r.BuffersWritten=Read(p,92);
            r.BuffersLost=Read(p,96)+Read(p,100);
        }
        public static CaptureReport Capture(string etlPath, int seconds) {
            if (IntPtr.Size != 8 || seconds < 1 || seconds > 10) throw new ArgumentException("Requires x64 and 1..10 seconds");
            if(System.IO.File.Exists(etlPath))throw new ArgumentException("Refusing to overwrite an existing ETL");
            var report=new CaptureReport();
            IntPtr properties=Marshal.AllocHGlobal(PropertyBytes), ids=IntPtr.Zero, descriptor=IntPtr.Zero, parametersPointer=IntPtr.Zero;
            ulong handle=0; bool started=false;
            try {
                // EVENT_TRACE_PROPERTIES is 120 bytes on x64, followed by two 1024-WCHAR buffers.
                Marshal.Copy(new byte[PropertyBytes],0,properties,PropertyBytes);
                Marshal.WriteInt32(properties,0,PropertyBytes);
                Marshal.WriteInt32(properties,40,1); // QPC clock
                Marshal.WriteInt32(properties,44,0x20000); // WNODE_FLAG_TRACED_GUID
                Marshal.WriteInt32(properties,48,64); // KB per buffer
                Marshal.WriteInt32(properties,52,256);
                Marshal.WriteInt32(properties,56,1024);
                Marshal.WriteInt32(properties,60,128); // MB file cap; never circular overwrite
                Marshal.WriteInt32(properties,64,unchecked((int)(Independent|Sequential)));
                Marshal.WriteInt32(properties,68,1);
                Marshal.WriteInt32(properties,112,FileOffset);
                Marshal.WriteInt32(properties,116,NameOffset);
                WriteString(properties,NameOffset,SessionName); WriteString(properties,FileOffset,etlPath);
                report.StartExit=Start(out handle,SessionName,properties);
                if(report.StartExit!=0) throw new InvalidOperationException("StartTrace failed: "+report.StartExit);
                started=true;
                string[] providers={"802EC45A-1E99-4B83-9920-87C98277BA9D","9E9BBA3C-2E38-40CB-99F4-9E8281425164",
                    "CA11C036-0102-4A2D-A6AD-F03CFED5D3C9","783ACA0A-790E-4D7F-8451-AA850511C6B9","8C416C79-D49B-4F01-A467-E56D3AA8234C"};
                ulong[] masks={0x8000841UL,0x8000000000000081UL,0x8000000000000002UL,0x8000000000000002UL,0x8000000400001000UL};
                // Win32k token IDs only: explicitly exclude keyboard/message/input events.
                ids=Marshal.AllocHGlobal(8); Marshal.Copy(new byte[]{1,0,2,0,0xc9,0,0x2d,1},0,ids,8);
                descriptor=Marshal.AllocHGlobal(Marshal.SizeOf<FilterDescriptor>());
                Marshal.StructureToPtr(new FilterDescriptor {Pointer=unchecked((ulong)ids.ToInt64()),Size=8,Type=0x80000200},descriptor,false);
                for(int i=0;i<providers.Length;i++) {
                    var provider=new Guid(providers[i]);
                    var parameters=new EnableParameters {Version=2,EnableProperty=IgnoreKeywordZero,FilterDescriptor=descriptor,FilterCount=1};
                    if(i==4){
                        parametersPointer=Marshal.AllocHGlobal(Marshal.SizeOf<EnableParameters>());
                        Marshal.StructureToPtr(parameters,parametersPointer,false);
                    }
                    // Zero timeout is the documented asynchronous request, not proof of delivered events.
                    report.EnableExits[i]=Enable(handle,ref provider,1,(byte)(i==4?4:5),masks[i],0,0,i==4?parametersPointer:IntPtr.Zero);
                    if(report.EnableExits[i]!=0)throw new InvalidOperationException("EnableTrace failed: "+report.EnableExits[i]);
                }
                report.QueryExit=Query(handle,SessionName,properties,0);
                if(report.QueryExit!=0)throw new InvalidOperationException("QueryTrace failed: "+report.QueryExit);
                Statistics(report,properties);
                if((report.Mode&Independent)==0)throw new InvalidOperationException("Independent mode not applied");
                Thread.Sleep(seconds*1000);
            } catch(Exception e) { report.Error=e.Message; }
            finally {
                // A name collision (StartTrace 183) must never stop somebody else's session.
                if(started){report.StopExit=Stop(handle,SessionName,properties);Statistics(report,properties);}
                if(descriptor!=IntPtr.Zero)Marshal.FreeHGlobal(descriptor);
                if(parametersPointer!=IntPtr.Zero)Marshal.FreeHGlobal(parametersPointer);
                if(ids!=IntPtr.Zero)Marshal.FreeHGlobal(ids);
                Marshal.FreeHGlobal(properties);
            }
            return report;
        }
    }
}
