import { NativeModules, NativeEventEmitter } from "react-native";

const { RNAdvanceDownloader } = NativeModules;

export default class AdvanceDownloadManager {

    constructor() {
        this._priority = RNAdvanceDownloader.FIFO
        this._maxConcurrentDownloads = 3
        this._timeout = 15
        this._headers = new Map()
        this._cacheFolderPath = ""
        this._eventEmitter = new NativeEventEmitter(RNAdvanceDownloader)
        RNAdvanceDownloader.getCacheFolderPath((error, path) => this._cacheFolderPath = path)
        this._startEvent = null
        this._downloadEvent = null
        this._completeEvent = null
        this._stopEvent = null
    }

    set downloadPrioritization(value) {
        if (value === RNAdvanceDownloader.FIFO || value === RNAdvanceDownloader.LIFO) {
            this._priority = value
            RNAdvanceDownloader.setDownloadPrioritization(value)
        }
    }

    get downloadPrioritization() {
        return this._priority
    }

    get maxConcurrentDownloads() {
        return this._maxConcurrentDownloads
    }

    set maxConcurrentDownloads(val) {
        this._maxConcurrentDownloads = val
        RNAdvanceDownloader.setMaxConcurrentDownloads(val)
    }

    get timeout() {
        return this._timeout
    }

    set timeout(val) {
        this._timeout = val
        RNAdvanceDownloader.setDownloadTimeout(val)
    }

    set startEvent(cb) {
        if (!cb && this._startEvent) {
            this._startEvent.remove()
            this._startEvent = null
        } else if (cb && this._startEvent) {
            this._startEvent = this._eventEmitter.addListener("Start", cb)
        }
    }

    get startEvent() {
        return this._startEvent
    }

    set downloadEvent(cb) {
        if (!cb && this._downloadEvent) {
            this._downloadEvent.remove()
            this._downloadEvent = null
        } else if (cb && this._downloadEvent) {
            this._downloadEvent = this._eventEmitter.addListener("Downloading", cb)
        }
    }

    get downloadEvent() {
        return this._downloadEvent
    }

    set completeEvent(cb) {
        if (!cb && this._completeEvent) {
            this._completeEvent.remove()
            this._completeEvent = null
        } else if (cb && !this._completeEvent) {
            this._completeEvent = this._eventEmitter.addListener("Completed", cb)
        }
    }

    get completeEvent() {
        return this._completeEvent
    }

    set stopEvent(cb) {
        if (!cb && this._stopEvent) {
            this._stopEvent.remove()
            this._stopEvent = null
        } else if (cb && !this._stopEvent) {
            this._stopEvent = this._eventEmitter.add("Stop", cb)
        }
    }

    get stopEvent() {
        return this._stopEvent
    }

    removeAllEvents() {
        this.startEvent = null
        this.stopEvent = null
        this.downloadEvent = null
        this.completeEvent = null
    }

    addHTTPHeaderField(field, value) {
        this._headers.set(field, value)
        RNAdvanceDownloader.setHTTPHeader(value, field)
    }

    httpFieldValue(field) {
        return this._headers.get(field)
    }

    setCacheFolder(path) {
        this._cacheFolderPath = path
        return RNAdvanceDownloader.setCacheFolder(path)
    }

    get cahceFolderPath() {
        return this._cacheFolderPath
    }

    static cancelAllTasks() {
        RNAdvanceDownloader.cancelAllDownloads()
    }

    static set suspend(flag) {
        RNAdvanceDownloader.setSuspend(flag)
    }

    static cancelTask(url, cb) {
        RNAdvanceDownloader.cancelTask(url, (err, isSuccess) => {
            cb(isSuccess)
        })
    }

    static removeTask(url, cb) {
        RNAdvanceDownloader.removeTask(url, (error, isSuccess) => {
            cb(isSuccess)
        })
    }

    static taskState(url, cb) {
        RNAdvanceDownloader.taskState(url, (error, state) => {
            cb(state)
        })
    }

    static addDownloadTask(url) {
        RNAdvanceDownloader.addDownloadTask(url)
    }
}
