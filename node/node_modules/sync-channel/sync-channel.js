function SyncChannel() {
    this.writers = [];
    this.readers = [];
    this.syncing = false;
}

SyncChannel.prototype.tryRead = function () {
    if (this.writers.length > 0) {
        var writer = this.writers.shift();
        writer.continuation();
        return { value: writer.value };
    } else {
        return null;
    }
};
 
SyncChannel.prototype.tryWrite = function (value) {
    if (this.readers.length > 0) {
        var reader = this.readers.shift();
        reader.continuation(value);
        return true;
    } else {
        return false;
    }
};

SyncChannel.prototype.read = function (continuation) {
    var channel = this;
    var reader = { continuation: continuation };
    channel.readers.push(reader);
    if (!channel.syncing) channel.sync();
    return function cancel() {
        var index = channel.readers.indexOf(reader);
        channel.readers.splice(index, 1);
    }
};

SyncChannel.prototype.write = function (value, continuation) {
    continuation = continuation || function () { };
    var channel = this;
    var writer = { continuation: continuation, value: value };
    channel.writers.push(writer);
    if (!channel.syncing) channel.sync();
    return function cancel() {
        var index = channel.writers.indexOf(writer);
        channel.writers.splice(index, 1);
    }
};

SyncChannel.prototype.sync = function () {
    var channel = this;
    channel.syncing = true;
    (function loop() {
        setImmediate(function () {
            if (channel.readers.length > 0 && channel.writers.length > 0) {
                var reader = channel.readers.shift();
                var writer = channel.writers.shift();
                reader.continuation(writer.value);
                writer.continuation();
                loop();
            } else {
                channel.syncing = false;
            }
        });
    })();
};

module.exports = SyncChannel;
