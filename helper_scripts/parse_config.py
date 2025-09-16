#!/usr/bin/env python3
"""
Simple YAML configuration parser for RExPRT
Converts YAML config to bash environment variables
"""

import yaml
import os
import sys

def load_config(config_file):
    """Load configuration from YAML file"""
    try:
        with open(config_file, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Warning: Configuration file {config_file} not found, using defaults")
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing YAML configuration: {e}")
        return {}

def export_bash_variables(config):
    """Export configuration as bash environment variables"""
    if not config:
        # Set defaults
        print("export MAX_CPU_CORES=96")
        print("export MIN_CPU_CORES=1")
        print("export VERBOSE_PROGRESS=true")
        print("export ENABLE_LOGGING=false")
        print("export LOG_FILE='rexprt.log'")
        print("export ENABLE_TIMING=true")
        print("export TEMP_DIR='./tmp'")
        print("export ML_BATCH_SIZE=10000")
        print("export IO_BUFFER_SIZE=256")
        print("export MAX_BEDTOOLS_JOBS=4")
        print("export PARALLEL_NICE_LEVEL=10")
        print("export ENABLE_PARALLEL_BEDTOOLS=true")
        print("export ENABLE_MEMORY_OPTIMIZATION=true")
        print("export MAX_IN_MEMORY_SIZE=1000")
        return

    # CPU settings
    cpu = config.get('cpu', {})
    print(f"export MAX_CPU_CORES={cpu.get('max_cores', 96)}")
    print(f"export MIN_CPU_CORES={cpu.get('min_cores', 1)}")

    # Memory settings
    memory = config.get('memory', {})
    print(f"export ML_BATCH_SIZE={memory.get('ml_batch_size', 10000)}")
    print(f"export IO_BUFFER_SIZE={memory.get('io_buffer_size', 256)}")

    # Parallel settings
    parallel = config.get('parallel', {})
    print(f"export MAX_BEDTOOLS_JOBS={parallel.get('max_bedtools_jobs', 4)}")
    print(f"export PARALLEL_NICE_LEVEL={parallel.get('nice_level', 10)}")

    # Logging settings
    logging = config.get('logging', {})
    print(f"export VERBOSE_PROGRESS={logging.get('verbose_progress', True)}")
    print(f"export ENABLE_LOGGING={logging.get('enable_logging', False)}")
    print(f"export LOG_FILE='{logging.get('log_file', 'rexprt.log')}'")
    print(f"export ENABLE_TIMING={logging.get('enable_timing', True)}")

    # Filesystem settings
    filesystem = config.get('filesystem', {})
    print(f"export TEMP_DIR='{filesystem.get('temp_dir', './tmp')}'")

    # Performance settings
    performance = config.get('performance', {})
    print(f"export ENABLE_PARALLEL_BEDTOOLS={performance.get('enable_parallel_bedtools', True)}")
    print(f"export ENABLE_MEMORY_OPTIMIZATION={performance.get('enable_memory_optimization', True)}")
    print(f"export MAX_IN_MEMORY_SIZE={performance.get('max_in_memory_size', 1000)}")

if __name__ == "__main__":
    config_file = sys.argv[1] if len(sys.argv) > 1 else "rexprt_config.yml"
    config = load_config(config_file)
    export_bash_variables(config)
