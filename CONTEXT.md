# Domain context

## Generated feed card

A catalog-backed commerce surface constructed around a shopping job, not selected by visual novelty. The sequence is Signal → Shopping job → Content → Composition → Interaction. Generation chooses semantic hierarchy and supported interactions; Shop's renderer owns visual values. Merchant identity, product identity, imagery, price, and destination remain canonical source data.

## Shopping signal

Activity or context that makes a shopping job relevant. Signals have provenance. The four-card feed prototype uses explicitly simulated activity; these fixtures are not facts about the real buyer.

## Shopping job

The useful progress an experience supports now, such as completing a purchase, comparing candidates, exploring a merchant, or continuing a World. Determine the job before selecting products and composition.

## Card grammar

The finite set of trusted presentation and interaction structures available to generated feed cards. A grammar creates variety without allowing generation to invent commerce facts or arbitrary interface behavior.

## Card specification

The interface between generation and rendering: stable identity, source signal, shopping job, canonical anchor/candidate references, semantic composition, copy, local interaction, context and rationale. Alternate compositions retain the same entities and session state. Arbitrary fonts, color values, spacing and animation curves are not generated.

## World

A dynamic, personalized, stateful, steerable, and shoppable experience organized around something that matters to a shopper now. A World is the shopping journey and its remembered context, not a page template.

## World identity

The stable description of why a World exists, what shopping job it serves, and who or what it concerns.

## World experience form

The interface through which someone currently explores a World. The supported forms are merchandised, canvas, try-on, spatial, gifting, and mission. One World may expose multiple forms without becoming multiple Worlds.

## World context

What Shop currently understands while constructing a World. Context has three scopes: buyer context, subject context, and local World context. Explicit local information takes precedence over subject knowledge, which takes precedence over global buyer knowledge and Shop inference.

## Subject

The person, place, or objective a World concerns. The shopper can be the subject, but does not have to be. León is the subject of the gifting World while Luke remains the buyer.

## World state

What has happened during a shopping journey, including products explored, saved, rejected, or purchased; steering instructions; completed mission steps; and visits to deeper Worlds.

## World action

A meaningful shopper input that may alter World context, state, presentation, or available paths. Pills, text, voice, and direct manipulation are input methods for World actions.

## World path

An available route from one World into a more specific World. A path carries relevant context into the destination and defines which outcomes can return.

## Child World

A World created when a shopper narrows into a distinct objective worth remembering and revisiting independently. Changing an interface form or applying a lightweight constraint does not by itself create a child World.

## World origin

How a World was entered: directly from a feed, through a related World, or as a child of another World session. Origin does not determine the World’s experience form.

## World lifetime

How long a World remains relevant. Worlds may be persistent, session-only, or ephemeral. Expiring a World does not require forgetting durable buyer or subject knowledge learned through it.

## Recommendation explanation

On-demand reasoning for why a World, section, merchant, or product appeared. Explanations are available through an explicit details action and remain out of the primary shopping interface.
