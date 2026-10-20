#!/usr/bin/env swift
//
// 앱 아이콘 생성기.
//
// SF Symbol 과 그래디언트로 1024pt 아이콘을 그리고, macOS 표준 .iconset 을
// 만든 뒤 iconutil 로 .icns 로 변환한다.
//
//   swift scripts/make-icon.swift
//
import AppKit
import Foundation

let root = FileManager.default.currentDirectoryPath
let iconsetPath = "\(root)/Resources/AppIcon.iconset"
let icnsPath = "\(root)/Resources/AppIcon.icns"

let canvas = NSSize(width: 1024, height: 1024)

// MARK: - 배경(맥 아이콘 관례: 둥근 사각형 + 세로 그라디언트)

let shape = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: canvas.width, height: canvas.height),
    xRadius: 224,
    yRadius: 224
)

let image = NSImage(size: canvas)
image.lockFocus()

let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.25, alpha: 1),
    ending: NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 1)
)
gradient?.draw(in: shape, angle: -90)

// 상단 하이라이트(유리 느낌)
NSGraphicsContext.current?.saveGraphicsState()
shape.addClip()
let highlight = NSGradient(
    starting: NSColor(white: 1, alpha: 0.18),
    ending: NSColor(white: 1, alpha: 0)
)
highlight?.draw(
    in: NSRect(x: 0, y: canvas.height * 0.45, width: canvas.width, height: canvas.height * 0.55),
    angle: -90
)
NSGraphicsContext.current?.restoreGraphicsState()

// MARK: - 게이지 심볼

let symbolConfig = NSImage.SymbolConfiguration(pointSize: 420, weight: .medium)
guard let gauge = NSImage(
    systemSymbolName: "gauge.with.dots.needle.67percent",
    accessibilityDescription: nil
)?.withSymbolConfiguration(symbolConfig) else {
    FileHandle.standardError.write(Data("심볼을 찾을 수 없습니다.\n".utf8))
    exit(1)
}

// 심볼을 흰색으로 틴트한다(템플릿 이미지는 기본 검정으로 그려진다).
let tinted = NSImage(size: gauge.size)
tinted.lockFocus()
gauge.draw(in: NSRect(origin: .zero, size: gauge.size))
NSColor.white.setFill()
NSRect(origin: .zero, size: gauge.size).fill(using: .sourceAtop)
tinted.unlockFocus()

let symbolSize = tinted.size
let symbolRect = NSRect(
    x: (canvas.width - symbolSize.width) / 2,
    y: (canvas.height - symbolSize.height) / 2,
    width: symbolSize.width,
    height: symbolSize.height
)
tinted.draw(in: symbolRect)

// 하단 상태 표시: 사용률 바(초록 → 주황)
let barRect = NSRect(
    x: canvas.width * 0.26,
    y: canvas.height * 0.24,
    width: canvas.width * 0.48,
    height: canvas.height * 0.035
)
let barPath = NSBezierPath(roundedRect: barRect, xRadius: barRect.height / 2, yRadius: barRect.height / 2)
NSColor(calibratedWhite: 1, alpha: 0.18).setFill()
barPath.fill()
let fillRect = NSRect(
    x: barRect.minX,
    y: barRect.minY,
    width: barRect.width * 0.34,
    height: barRect.height
)
let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: fillRect.height / 2, yRadius: fillRect.height / 2)
NSColor(calibratedRed: 0.30, green: 0.76, blue: 0.47, alpha: 1).setFill()
fillPath.fill()

image.unlockFocus()

// MARK: - PNG 내보내기

let variants: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

try? FileManager.default.createDirectory(
    atPath: iconsetPath,
    withIntermediateDirectories: true
)

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let fullPNG = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("아이콘 렌더링에 실패했습니다.\n".utf8))
    exit(1)
}

for variant in variants {
    let side = variant.size
    let resized = NSImage(size: NSSize(width: side, height: side))
    resized.lockFocus()
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    image.draw(
        in: NSRect(x: 0, y: 0, width: side, height: side),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { continue }
    try png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(variant.name).png"))
}

print("아이콘 세트 생성: \(iconsetPath)")
