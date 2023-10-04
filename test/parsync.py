#!/usr/bin/env python3
import os, queue, logging, subprocess

from logging.handlers import QueueHandler, QueueListener
from multiprocessing import Queue, Process, Manager, Semaphore
from threading import Thread
from collections import defaultdict
from time import sleep

class Parsync():
    def __init__(self, flags, source, destination, max_jobs, files_per_job):
        
        self.flags = "-av" if flags is None else flags
        self.source = source
        self.dest = destination
        self.job_limit = max_jobs
        self.file_limit = files_per_job

        self.processes = []

        self.child = defaultdict(list)
        self.child['name'] = [
                'Ada','Billy','Dave','Grace','John','Ken',
                'Linda','Marge','Nick','Saron','Tim'
            ]
        
        self.sema = Semaphore(self.job_limit)

        self.log_queue = Queue()
        self.logger = logging.getLogger("PARSYNC")

    def __enter__(self):
        self.logger.addHandler(QueueHandler(self.log_queue))
        self.logger.setLevel(logging.DEBUG)

        formatter = logging.Formatter(
            "{asctime:} - {name:^7s} - {levelname:>7s}: {message}", style='{'
        )

        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)

        self.listener = QueueListener(self.log_queue, console_handler)     
        self.listener.start()

        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.listener.stop()

    def run(self):
        self.logger.info("Running Parsync..")

        with Manager() as manager:
            self.child['active'] = manager.list()

            file_list = []
            for dirpath, subdir, files in os.walk(self.source):

                for file in files:
                    file_list.append(os.path.join(dirpath, file))
                    if len(file_list) >= self.file_limit:
                        self.process(file_list)
                        file_list.clear()
                    
                if len(file_list) > 0:
                    self.process(file_list)
                    file_list.clear()
            
            for proc in self.processes:
                proc.join()

    def process(self, files):
        if len(self.child['current']) == 0:
            index = 0
        else:
            index = self.child['name'].index(self.child['current'])
            index += 1

        if index > len(self.child['name'])-1:
            index = 0

        self.child['current'] = self.child['name'][index]

        self.sema.acquire()
        proc = Process(target=self.task, args=(files,))
        proc.start()

        self.processes.append(proc)

    def task(self, files):
        task_name = self.child['current']

        if task_name in self.child['active']:
            child_count = self.child['active'].count(task_name)
            task_name += f"{child_count:02d}"

        self.child['active'].append(self.child['current'])
        
        logger = logging.getLogger(str(task_name).upper())
        logger.addHandler(QueueHandler(self.log_queue))
        logger.setLevel(logging.DEBUG)

        logger.debug("Running Task..")

        subbase =  ['rsync','--ignore-existing']
        subarguments = subbase + self.flags \
                        if isinstance(self.flags, list) else subbase + [self.flags]

        for file in files:
            dest = os.path.join(
                    os.path.dirname(str(file).replace(self.source, self.dest)),''
            )

            subargs = subarguments + [file, dest]

            proc = subprocess.Popen(subargs, 
                    stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE, text=True)

            log = {'out': logger.info, 'err': self.logger.warning}
            for name, line in self.merge_pipes(out=proc.stdout, err=proc.stderr):
                log[name](line)

        proc.wait()
        self.sema.release()
        self.child['active'].remove(self.child['current'])
        
        logger.debug("Task Complete")

        return True
    
    def merge_pipes(self,**named_pipes):
        PIPE_OPENED=1
        PIPE_OUTPUT=2
        PIPE_CLOSED=3

        output = queue.Queue()
        def pipe_reader(name, pipe):
            output.put( ( PIPE_OPENED, name, ) )
            try:
                for line in iter(pipe.readline, ''):
                    output.put((PIPE_OUTPUT, name, line.rstrip(),))
                    sleep(0.05)
            finally:
                output.put((PIPE_CLOSED, name,))

        for name, pipe in named_pipes.items():
            reader=Thread(target=pipe_reader, args=(name, pipe, ))
            reader.daemon = True
            reader.start()
        
        pipe_count = 0

        for data in iter(output.get,''):
            code=data[0]
            if code == PIPE_OPENED:
                pipe_count += 1
            elif code == PIPE_CLOSED:
                pipe_count -= 1
            elif code == PIPE_OUTPUT:
                yield data[1:]
            if pipe_count == 0:
                return

with Parsync(
    flags=None, # example: ['-azv', '--info=progress2']. Default -av
    max_jobs=10, # max number of jobs you allow
    files_per_job=200, # max number of files to process per job
    source=r"/data/test/source/",
    destination=r"/data/test/destination/"
) as parsync:
    parsync.run()
