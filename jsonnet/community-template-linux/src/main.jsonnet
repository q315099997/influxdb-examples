local influxdb = import '../influxdb-jsonnet/src/influxdb.libsonnet';

local inputLabelColor = "#326BBA";
local outputLabelColor = "#108174";

local labelLinuxSystemTemplate = influxdb.label.new(name="Linux System Template", color="#7A65F2");

local labelInputsCPU = influxdb.label.new(name="inputs.cpu", color=inputLabelColor);
local labelInputsDisk = influxdb.label.new(name="inputs.disk", color=inputLabelColor);
local labelInputsDiskIO = influxdb.label.new(name="inputs.diskio", color=inputLabelColor);
local labelInputsKernel = influxdb.label.new(name="inputs.kernel", color=inputLabelColor);
local labelInputsMem = influxdb.label.new(name="inputs.mem", color=inputLabelColor);
local labelInputsNet = influxdb.label.new(name="inputs.net", color=inputLabelColor);
local labelInputsProcesses = influxdb.label.new(name="inputs.processes", color=inputLabelColor);
local labelInputsSwap = influxdb.label.new(name="inputs.swap", color=inputLabelColor);
local labelInputsSystem = influxdb.label.new(name="inputs.system", color=inputLabelColor);
local labelOutputsInfluxDB2 = influxdb.label.new(name="outputs.influxdb_v2", color=outputLabelColor);

local variableBucket = influxdb.variable.query.new(name="bucket", language="flux", query=|||
        buckets()
        |> filter(fn: (r) => r.name !~ /^_/)
        |> rename(columns: {name: "_value"})
        |> keep(columns: ["_value"])
|||);

local variableHost = influxdb.variable.query.new(name="linux_host", language="flux", query=|||
        import "influxdata/influxdb/v1"
        v1.measurementTagValues(bucket: v.bucket, measurement: "cpu", tag: "host")
|||);

[
    labelLinuxSystemTemplate,
    labelInputsCPU,
    labelInputsDisk,
    labelInputsDiskIO,
    labelInputsKernel,
    labelInputsMem,
    labelInputsNet,
    labelInputsProcesses,
    labelInputsSwap,
    labelInputsSystem,
    labelOutputsInfluxDB2,
    
    variableBucket,
    variableHost,

    influxdb.bucket.new(name="telegraf", retentionRules=[{type: "expire", everySeconds: 604800}]),

    influxdb.telegraf.new(name="Linux System Monitoring", labels=[labelInputsCPU, labelInputsSystem, labelInputsSwap, labelInputsProcesses, labelInputsMem, labelInputsKernel, labelInputsDisk, labelInputsDiskIO, labelLinuxSystemTemplate, labelOutputsInfluxDB2], config=|||
        # Telegraf Configuration
        #
        # Telegraf is entirely plugin driven. All metrics are gathered from the
        # declared inputs, and sent to the declared outputs.
        #
        # Plugins must be declared in here to be active.
        # To deactivate a plugin, comment out the name and any variables.
        #
        # Use 'telegraf -config telegraf.conf -test' to see what metrics a config
        # file would generate.
        #
        # Environment variables can be used anywhere in this config file, simply surround
        # them with ${}. For strings the variable must be within quotes (ie, "${STR_VAR}"),
        # for numbers and booleans they should be plain (ie, ${INT_VAR}, ${BOOL_VAR})


        # Global tags can be specified here in key="value" format.
        [global_tags]
          # dc = "us-east-1" # will tag all metrics with dc=us-east-1
          # rack = "1a"
          ## Environment variables can be used as tags, and throughout the config file
          # user = "$USER"


        # Configuration for telegraf agent
        [agent]
          ## Default data collection interval for all inputs
          interval = "10s"
          ## Rounds collection interval to 'interval'
          ## ie, if interval="10s" then always collect on :00, :10, :20, etc.
          round_interval = true

          ## Telegraf will send metrics to outputs in batches of at most
          ## metric_batch_size metrics.
          ## This controls the size of writes that Telegraf sends to output plugins.
          metric_batch_size = 1000

          ## Maximum number of unwritten metrics per output.  Increasing this value
          ## allows for longer periods of output downtime without dropping metrics at the
          ## cost of higher maximum memory usage.
          metric_buffer_limit = 10000

          ## Collection jitter is used to jitter the collection by a random amount.
          ## Each plugin will sleep for a random time within jitter before collecting.
          ## This can be used to avoid many plugins querying things like sysfs at the
          ## same time, which can have a measurable effect on the system.
          collection_jitter = "0s"

          ## Default flushing interval for all outputs. Maximum flush_interval will be
          ## flush_interval + flush_jitter
          flush_interval = "10s"
          ## Jitter the flush interval by a random amount. This is primarily to avoid
          ## large write spikes for users running a large number of telegraf instances.
          ## ie, a jitter of 5s and interval 10s means flushes will happen every 10-15s
          flush_jitter = "0s"

          ## By default or when set to "0s", precision will be set to the same
          ## timestamp order as the collection interval, with the maximum being 1s.
          ##   ie, when interval = "10s", precision will be "1s"
          ##       when interval = "250ms", precision will be "1ms"
          ## Precision will NOT be used for service inputs. It is up to each individual
          ## service input to set the timestamp at the appropriate precision.
          ## Valid time units are "ns", "us" (or "µs"), "ms", "s".
          precision = ""

          ## Log at debug level.
          # debug = false
          ## Log only error level messages.
          # quiet = false

          ## Log target controls the destination for logs and can be one of "file",
          ## "stderr" or, on Windows, "eventlog".  When set to "file", the output file
          ## is determined by the "logfile" setting.
          # logtarget = "file"

          ## Name of the file to be logged to when using the "file" logtarget.  If set to
          ## the empty string then logs are written to stderr.
          # logfile = ""

          ## The logfile will be rotated after the time interval specified.  When set
          ## to 0 no time based rotation is performed.  Logs are rotated only when
          ## written to, if there is no log activity rotation may be delayed.
          # logfile_rotation_interval = "0d"

          ## The logfile will be rotated when it becomes larger than the specified
          ## size.  When set to 0 no size based rotation is performed.
          # logfile_rotation_max_size = "0MB"

          ## Maximum number of rotated archives to keep, any older logs are deleted.
          ## If set to -1, no archives are removed.
          # logfile_rotation_max_archives = 5

          ## Override default hostname, if empty use os.Hostname()
          hostname = ""
          ## If set to true, do no set the "host" tag in the telegraf agent.
          omit_hostname = false


        ###############################################################################
        #                            OUTPUT PLUGINS                                   #
        ###############################################################################

        # Configuration for sending metrics to InfluxDB
        [[outputs.influxdb_v2]]
          ## The URLs of the InfluxDB cluster nodes.
          ##
          ## Multiple URLs can be specified for a single cluster, only ONE of the
          ## urls will be written to each interval.
          ##   ex: urls = ["https://us-west-2-1.aws.cloud2.influxdata.com"]
          urls = ["$INFLUX_HOST"]
          ## Token for authentication.
          token = "$INFLUX_TOKEN"
          ## Organization is the name of the organization you wish to write to; must exist.
          organization = "$INFLUX_ORG"
          ## Destination bucket to write into.
          bucket = "telegraf"
          ## The value of this tag will be used to determine the bucket.  If this
          ## tag is not set the 'bucket' option is used as the default.
          # bucket_tag = ""
          ## If true, the bucket tag will not be added to the metric.
          # exclude_bucket_tag = false
          ## Timeout for HTTP messages.
          # timeout = "5s"
          ## Additional HTTP headers
          # http_headers = {"X-Special-Header" = "Special-Value"}
          ## HTTP Proxy override, if unset values the standard proxy environment
          ## variables are consulted to determine which proxy, if any, should be used.
          # http_proxy = "http://corporate.proxy:3128"
          ## HTTP User-Agent
          # user_agent = "telegraf"
          ## Content-Encoding for write request body, can be set to "gzip" to
          ## compress body or "identity" to apply no encoding.
          # content_encoding = "gzip"
          ## Enable or disable uint support for writing uints influxdb 2.0.
          # influx_uint_support = false
          ## Optional TLS Config for use on HTTP connections.
          # tls_ca = "/etc/telegraf/ca.pem"
          # tls_cert = "/etc/telegraf/cert.pem"
          # tls_key = "/etc/telegraf/key.pem"
          ## Use TLS but skip chain & host verification
          # insecure_skip_verify = false

        ###############################################################################
        #                            INPUT PLUGINS                                    #
        ###############################################################################


        # Read metrics about cpu usage
        [[inputs.cpu]]
          ## Whether to report per-cpu stats or not
          percpu = true
          ## Whether to report total system cpu stats or not
          totalcpu = true
          ## If true, collect raw CPU time metrics.
          collect_cpu_time = false
          ## If true, compute and report the sum of all non-idle CPU states.
          report_active = false


        # Read metrics about disk usage by mount point
        [[inputs.disk]]
          ## By default stats will be gathered for all mount points.
          ## Set mount_points will restrict the stats to only the specified mount points.
          # mount_points = ["/"]

          ## Ignore mount points by filesystem type.
          ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]


        # Read metrics about disk IO by device
        [[inputs.diskio]]
          ## By default, telegraf will gather stats for all devices including
          ## disk partitions.
          ## Setting devices will restrict the stats to the specified devices.
          # devices = ["sda", "sdb", "vd*"]
          ## Uncomment the following line if you need disk serial numbers.
          # skip_serial_number = false
          #
          ## On systems which support it, device metadata can be added in the form of
          ## tags.
          ## Currently only Linux is supported via udev properties. You can view
          ## available properties for a device by running:
          ## 'udevadm info -q property -n /dev/sda'
          ## Note: Most, but not all, udev properties can be accessed this way. Properties
          ## that are currently inaccessible include DEVTYPE, DEVNAME, and DEVPATH.
          # device_tags = ["ID_FS_TYPE", "ID_FS_USAGE"]
          #
          ## Using the same metadata source as device_tags, you can also customize the
          ## name of the device via templates.
          ## The 'name_templates' parameter is a list of templates to try and apply to
          ## the device. The template may contain variables in the form of '$PROPERTY' or
          ## '${PROPERTY}'. The first template which does not contain any variables not
          ## present for the device is used as the device name tag.
          ## The typical use case is for LVM volumes, to get the VG/LV name instead of
          ## the near-meaningless DM-0 name.
          # name_templates = ["$ID_FS_LABEL","$DM_VG_NAME/$DM_LV_NAME"]


        # Get kernel statistics from /proc/stat
        [[inputs.kernel]]
          # no configuration


        # Read metrics about memory usage
        [[inputs.mem]]
          # no configuration

        # Read metrics about network interface usage
        [[inputs.net]]
          ## By default, telegraf gathers stats from any up interface (excluding loopback)
          ## Setting interfaces will tell it to gather these explicit interfaces,
          ## regardless of status.
          ##
          # interfaces = ["eth0"]
          ##
          ## On linux systems telegraf also collects protocol stats.
          ## Setting ignore_protocol_stats to true will skip reporting of protocol metrics.
          ##
          # ignore_protocol_stats = false
          ##

        # Get the number of processes and group them by status
        [[inputs.processes]]
          # no configuration


        # Read metrics about swap memory usage
        [[inputs.swap]]
          # no configuration


        # Read metrics about system load & uptime
        [[inputs.system]]
          ## Uncomment to remove deprecated metrics.
          # fielddrop = ["uptime_format"]
|||),

    influxdb.dashboard.new(name="Linux System", charts=[
        influxdb.dashboard.charts.singleStat.new(
            name="System Uptime",
            queries=[
                influxdb.query.new(flux=|||
                    from(bucket: v.%(bucketName)s)
                    |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
                    |> filter(fn: (r) => r._measurement == "system")
                    |> filter(fn: (r) => r._field == "uptime")
                    |> filter(fn: (r) => r.host == v.linux_host)
                    |> last()
                    |> map(fn: (r) => ({ _value: float(v: r._value) / 86400.00 }))
                ||| % { bucketName: variableBucket.metadata.name})
            ],
            note="System Uptime"
        )
    ])
]
//   - colors:
//       - hex: '#00C9FF'
//         name: laser
//         type: text
//     height: 1
//     suffix: ' days'
//     width: 3
//     yPos: 1
