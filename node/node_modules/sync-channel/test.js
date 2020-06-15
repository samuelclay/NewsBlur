var SyncChannel = require('./SyncChannel');

function test1() {
    var channel = new SyncChannel();

    function thread1() {
        function loop() {
            channel.read(function (value) {
                if (value % 1000 === 0) {
                    console.log(value);
                }
                loop();
            });
        }
        loop();
    }

    function thread2() {
        var n = 0;
        function loop() {
            channel.write(n, function () {
                n++;
                loop();
            });
        }
        loop();
    }

    thread1();
    thread2();
}

test1();