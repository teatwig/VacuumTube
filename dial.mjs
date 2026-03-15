import { Server } from 'peer-dial';
import express from 'express';
import { hostname } from 'os';

// adapted from: https://github.com/marcosrg9/YouTubeTV/blob/2072dc0b406ce5fc70e234a87a035ed20253d281/servers/DIAL.ts

/**
 * @typedef App
 * @type {object}
 * @param {string} name
 * @param {('starting'|'running'|'stopped')} state
 * @param {boolean} allowStop
 * @param {string} pid
 * @param {(launchData: string): void} launch
 */

export class Dial {
    /**
     * Stores allowed apps.
     * @type {Record<string, App>}
     */
    _apps;
    /**
     * Stores the DIAL server.
     * @type {Server}
     */
    _dialServer;
    /**
     * Stores the express application server.
     * @type {express.Express}
     */
    _exServer = express();
    /** Stores the server port. */
    _port;
    /** Stores the server status. */
    _listening = false;

    /**
     * Instantiate a new DIAL server.
     * @param {string} friendlyName
     * @param {number} port
     * @param {(value: string) => void} urlByDial callback to switch to the URL
     */
    constructor(friendlyName, port, urlByDial) {
        if (!friendlyName) {
            const host = hostname();
            friendlyName = `VacuumTube on ${host}`;
        }
        this._friendlyName = friendlyName;
        this._port = port;

        // Basic DIAL server configuration.
        this._apps = {
            "YouTube": {
                name: 'YouTube',
                state: 'stopped',
                allowStop: true,
                pid: '',
                launch: (data) => urlByDial(data)
            }
        }

        this._dialServer = new Server({
            expressApp: this._exServer,
            manufacturer: 'VacuumTube',
            modelName: 'VacuumTube',
            port: this._port,
            prefix: '/dial',
            corsAllowOrigins: '*',
            friendlyName: this._friendlyName,
            delegate: {
                getApp: appName => {
                    return this._apps[appName];
                },
                launchApp: this._onAppLaunch.bind(this),
                stopApp: this._onAppStop.bind(this),
            }
        })
    }

    start() {
        if (!this._listening) {
            this._listen();
        } else {
            console.log('Starting DIAL server')
            this._dialServer.start();
        }
    }

    stop() {
        console.log('Stopping DIAL server')
        this._dialServer.stop();
        this._listening = false;
    }

    /**
     * Start listening to DIAL requests.
     * @param {number} port port number.
     */
    _listen() {
        console.log('Starting listener')
        this._exServer.listen(this._port, () => {
            console.log('Listener is ready, starting DIAL server');
            this._dialServer.start();
            this._listening = true;
        }).on('error', err => {
            if (err.code === 'EADDRINUSE') {
                // TODO
                this._listen(randomInt(1081, 65534));
                this._listening = false;
            }
        })
    }

    /**
     * Fires when device connects to the DIAL server.
     * @param {string} appName application name (we only have one)
     * @param {string} launchData pairing code etc to send to youtube tv
     * @param {(pid: string) => void} callback
     */
    _onAppLaunch(appName, launchData, callback) {
        const app = this._apps[appName];
        console.log('DIAL started');

        if (app) {
            app.pid = 'dummy_pid'; // we don't start a process, so we don't have a PID
            app.state = 'starting';
            // Interacts with the main renderer.
            app.launch(launchData);
            app.state = 'running';

            callback(app.pid);
        } else {
            // shouldn't happen since we only have one app
            throw new Error(`App ${appName} not found.`);
        }
    }

    /**
     * Fires when device disconnects from the DIAL server.
     * @param {string} appName application name
     * @param {string} pid pid of the app
     * @param {(boolean: string) => void} callback Executes disconnection
     */
    _onAppStop(appName, pid, callback) {
        const app = this._apps[appName];
        console.log('DIAL stopped');

        if (app && app.pid === pid) {
            app.pid = '';
            app.state = 'stopped';
            // Disconnects from device.
            callback(true);
        } else {
            // shouldn't happen since we only have one app
            callback(false);
        }
    }
}
